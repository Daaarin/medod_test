# == Schema Information
#
# Table name: task_occurrences
#
#  id           :bigint           not null, primary key
#  actual_at    :datetime
#  generated_at :datetime
#  postponed_to :datetime
#  scheduled_at :datetime         not null
#  skip_reason  :string
#  status       :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  task_id      :bigint           not null
#
# Indexes
#
#  index_task_occurrences_on_task_id               (task_id)
#  index_task_occurrences_on_task_id_and_status    (task_id,status)
#  index_task_occurrences_on_task_id_when_current  (task_id) UNIQUE WHERE ((status)::text = ANY ((ARRAY['planned'::character varying, 'postponed'::character varying])::text[]))
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id)
#
require "rails_helper"

RSpec.describe TaskOccurrence, type: :model do
  it "exposes the planned lifecycle and allows one current future occurrence per task" do
    expect(described_class.statuses.keys).to match_array(%w[planned postponed executed skipped superseded cancelled])

    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    duplicate = task.task_occurrences.new(
      scheduled_at: Time.zone.parse("2026-05-19 10:00"),
      status: :planned
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:task_id]).to include("already has a current occurrence")
  end

  it "treats planned and postponed occurrences as the same current slot" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :postponed,
      postponed_to: Time.zone.parse("2026-05-12 14:00")
    )

    planned = task.task_occurrences.new(
      scheduled_at: Time.zone.parse("2026-05-13 10:00"),
      status: :planned
    )

    expect(planned).not_to be_valid
    expect(planned.errors[:task_id]).to include("already has a current occurrence")

    task.task_occurrences.destroy_all
    task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    postponed = task.task_occurrences.new(
      scheduled_at: Time.zone.parse("2026-05-13 10:00"),
      status: :postponed,
      postponed_to: Time.zone.parse("2026-05-13 14:00")
    )

    expect(postponed).not_to be_valid
    expect(postponed.errors[:task_id]).to include("already has a current occurrence")
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
