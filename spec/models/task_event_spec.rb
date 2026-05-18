# == Schema Information
#
# Table name: task_events
#
#  id            :bigint           not null, primary key
#  event_type    :string           not null
#  occurred_at   :datetime         not null
#  payload_json  :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  actor_id      :bigint           not null
#  occurrence_id :bigint
#  task_id       :bigint           not null
#
# Indexes
#
#  index_task_events_on_actor_id       (actor_id)
#  index_task_events_on_event_type     (event_type)
#  index_task_events_on_occurred_at    (occurred_at)
#  index_task_events_on_occurrence_id  (occurrence_id)
#  index_task_events_on_task_id        (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (occurrence_id => task_occurrences.id)
#  fk_rails_...  (task_id => tasks.id)
#
require "rails_helper"

RSpec.describe TaskEvent, type: :model do
  it "exposes append-only event history and persists payload data" do
    expect(described_class.event_types.keys).to include("created", "split")

    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    event = described_class.create!(
      task: task,
      event_type: :created,
      actor_id: responsible.id,
      occurred_at: Time.zone.parse("2026-05-10 09:00"),
      payload_json: { name: "Check email" }
    )

    expect(event.payload_json["name"]).to eq("Check email")
    expect(event.update(payload_json: { name: "Updated" })).to be(false)
    expect(event.errors[:base]).to include("task events are append-only")
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
