require "rails_helper"

RSpec.describe TaskScheduling::CalendarProjection do
  let(:zone) { ActiveSupport::TimeZone["Europe/Moscow"] }

  it "returns projected entries for every_n_days within the requested range" do
    task = build_recurring_task(
      rule_type: :every_n_days,
      interval_value: 2,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    projected = described_class.call(
      task: task,
      range_start: zone.parse("2026-05-01 00:00"),
      range_end: zone.parse("2026-05-10 23:59")
    )

    expect(projected).to all(satisfy { |time| time.time_zone.name == "Europe/Moscow" })
    expect(projected.map { |time| time.to_date }).to eq(
      [ Date.new(2026, 5, 1), Date.new(2026, 5, 3), Date.new(2026, 5, 5), Date.new(2026, 5, 7), Date.new(2026, 5, 9) ]
    )
  end

  it "returns only the one-time task occurrence when it falls in range" do
    task = Task.new(
      task_kind: :one_time,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42,
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
    task = Task.new(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    task.build_recurrence_rule(rule_attributes)
    task
  end
end
