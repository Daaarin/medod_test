require "rails_helper"

RSpec.describe TaskScheduling::CalendarProjection do
  let(:zone) { ActiveSupport::TimeZone["Europe/Moscow"] }

  it "returns projected entries for every_n_days within the requested range and stops at date_end" do
    task = build_recurring_task(
      rule_type: :every_n_days,
      interval_value: 2,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1),
      date_end: Date.new(2026, 5, 5)
    )

    projected = described_class.call(
      task: task,
      range_start: zone.parse("2026-05-01 00:00"),
      range_end: zone.parse("2026-05-10 23:59")
    )

    expect(projected).to all(satisfy { |time| time.time_zone.name == "Europe/Moscow" })
    expect(projected.map { |time| time.to_date }).to eq(
      [ Date.new(2026, 5, 1), Date.new(2026, 5, 3), Date.new(2026, 5, 5) ]
    )
  end

  it "returns projected entries for every_n_months within the requested range" do
    task = build_recurring_task(
      rule_type: :every_n_months,
      interval_value: 2,
      day_of_month: 15,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 1, 1)
    )

    projected = described_class.call(
      task: task,
      range_start: zone.parse("2026-01-01 00:00"),
      range_end: zone.parse("2026-05-31 23:59")
    )

    expect(projected.map { |time| time.to_date }).to eq(
      [ Date.new(2026, 1, 15), Date.new(2026, 3, 15), Date.new(2026, 5, 15) ]
    )
  end

  it "returns projected entries for every_n_years within the requested range" do
    task = build_recurring_task(
      rule_type: :every_n_years,
      interval_value: 1,
      month_of_year: 2,
      day_of_month: 29,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2024, 2, 29)
    )

    projected = described_class.call(
      task: task,
      range_start: zone.parse("2024-01-01 00:00"),
      range_end: zone.parse("2025-03-01 23:59")
    )

    expect(projected.map { |time| time.to_date }).to eq(
      [ Date.new(2024, 2, 29), Date.new(2025, 2, 28) ]
    )
  end

  it "returns projected entries for even day-of-month parity within the requested range" do
    task = build_recurring_task(
      rule_type: :day_of_month_parity,
      day_of_month_parity: :even,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    projected = described_class.call(
      task: task,
      range_start: zone.parse("2026-05-01 00:00"),
      range_end: zone.parse("2026-05-10 23:59")
    )

    expect(projected.map { |time| time.to_date }).to eq(
      [ Date.new(2026, 5, 2), Date.new(2026, 5, 4), Date.new(2026, 5, 6), Date.new(2026, 5, 8), Date.new(2026, 5, 10) ]
    )
  end

  it "returns projected entries for odd ISO weekday parity within the requested range" do
    task = build_recurring_task(
      rule_type: :weekday_parity,
      weekday_parity: :odd,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    projected = described_class.call(
      task: task,
      range_start: zone.parse("2026-05-01 00:00"),
      range_end: zone.parse("2026-05-07 23:59")
    )

    expect(projected.map { |time| time.to_date }).to eq(
      [ Date.new(2026, 5, 1), Date.new(2026, 5, 3), Date.new(2026, 5, 4), Date.new(2026, 5, 6) ]
    )
  end

  it "returns projected entries for specific dates within the requested range without creating rows" do
    task = build_recurring_task(
      rule_type: :specific_dates,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1),
      date_end: Date.new(2026, 5, 31),
      recurrence_rule_dates_attributes: [
        { run_date: Date.new(2026, 5, 20) },
        { run_date: Date.new(2026, 5, 12) },
        { run_date: Date.new(2026, 5, 15) }
      ]
    )

    before_count = task.task_occurrences.count

    projected = described_class.call(
      task: task,
      range_start: zone.parse("2026-05-01 00:00"),
      range_end: zone.parse("2026-05-31 23:59")
    )

    expect(projected.map { |time| time.to_date }).to eq(
      [ Date.new(2026, 5, 12), Date.new(2026, 5, 15), Date.new(2026, 5, 20) ]
    )
    expect(task.task_occurrences.count).to eq(before_count)
  end

  it "keeps every_n_days projections aligned across a spring-forward DST transition" do
    task = build_recurring_task(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "02:30",
      timezone: "America/New_York",
      date_start: Date.new(2026, 3, 7)
    )

    projected = described_class.call(
      task: task,
      range_start: ActiveSupport::TimeZone["America/New_York"].parse("2026-03-07 00:00"),
      range_end: ActiveSupport::TimeZone["America/New_York"].parse("2026-03-09 23:59")
    )

    expect(projected).to eq(
      [
        ActiveSupport::TimeZone["America/New_York"].parse("2026-03-07 02:30"),
        ActiveSupport::TimeZone["America/New_York"].parse("2026-03-08 03:30"),
        ActiveSupport::TimeZone["America/New_York"].parse("2026-03-09 02:30")
      ]
    )
  end

  it "projects postponed persisted occurrences before future generated recurrence entries" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible,
      first_run_at: zone.parse("2026-05-11 10:00"),
      next_run_at: zone.parse("2026-05-12 14:00")
    )
    task.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 11)
    )
    task.task_occurrences.create!(
      scheduled_at: zone.parse("2026-05-11 10:00"),
      status: :postponed,
      postponed_to: zone.parse("2026-05-12 14:00")
    )

    projected = described_class.call(
      task: task,
      range_start: zone.parse("2026-05-11 00:00"),
      range_end: zone.parse("2026-05-13 23:59")
    )

    expect(projected).to eq(
      [
        zone.parse("2026-05-12 14:00"),
        zone.parse("2026-05-13 10:00")
      ]
    )
  end

  it "returns only the one-time task occurrence when it falls in range" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.new(
      task_kind: :one_time,
      status: :ongoing,
      name: "Check email",
      responsible: responsible,
      next_run_at: zone.parse("2026-05-12 10:00")
    )

    projected = described_class.call(
      task: task,
      range_start: zone.parse("2026-05-11 00:00"),
      range_end: zone.parse("2026-05-12 23:59")
    )

    expect(projected).to eq([ zone.parse("2026-05-12 10:00") ])
  end

  it "returns no entries outside the requested range" do
    task = build_recurring_task(
      rule_type: :weekday_parity,
      weekday_parity: :odd,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    projected = described_class.call(
      task: task,
      range_start: zone.parse("2026-05-12 00:00"),
      range_end: zone.parse("2026-05-12 23:59")
    )

    expect(projected).to eq([])
  end

  def build_recurring_task(**rule_attributes)
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.new(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    task.build_recurrence_rule(rule_attributes)
    task
  end

  def build_user(email:, role:)
    User.create!(
      email:,
      password: "password123",
      role:,
      name: "Test",
      last_name: "User"
    )
  end
end
