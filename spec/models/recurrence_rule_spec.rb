require "rails_helper"

RSpec.describe RecurrenceRule, type: :model do
  it "exposes the supported recurrence shapes" do
    expect(described_class.rule_types.keys).to match_array(
      %w[every_n_days every_n_months every_n_years day_of_month_parity weekday_parity]
    )
  end

  it "accepts parity-based day and weekday selectors" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    rule = task.build_recurrence_rule(
      rule_type: :day_of_month_parity,
      day_of_month_parity: :even,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    expect(rule).to be_valid
  end
end
