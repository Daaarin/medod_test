# == Schema Information
#
# Table name: task_tags
#
#  id             :bigint           not null, primary key
#  deactivated_at :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  tag_id         :bigint           not null
#  task_id        :bigint           not null
#
# Indexes
#
#  index_task_tags_on_tag_id              (tag_id)
#  index_task_tags_on_task_id             (task_id)
#  index_task_tags_on_task_id_and_tag_id  (task_id,tag_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tag_id => tags.id)
#  fk_rails_...  (task_id => tasks.id)
#
require "rails_helper"

RSpec.describe TaskTag, type: :model do
  it "attaches, detaches, and reactivates the same join row" do
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Review labs",
      responsible: build_user(email: "responsible@example.test", role: :doctor)
    )
    tag = Tag.create!(name: "Operations")

    task_tag = described_class.attach!(task: task, tag: tag)

    expect(task_tag).to be_active
    expect(task_tag.task).to eq(task)
    expect(task_tag.tag).to eq(tag)

    task_tag_id = task_tag.id

    described_class.detach!(task: task, tag: tag)

    expect(task_tag.reload.deactivated_at).to be_present

    reactivated = described_class.attach!(task: task, tag: tag)

    expect(reactivated.id).to eq(task_tag_id)
    expect(reactivated.reload.deactivated_at).to be_nil
  end

  it "rejects duplicate task and tag rows" do
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Review labs",
      responsible: build_user(email: "responsible@example.test", role: :doctor)
    )
    tag = Tag.create!(name: "Call")

    described_class.create!(task: task, tag: tag)
    duplicate = described_class.new(task: task, tag: tag)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:task_id]).to include("has already been taken")
  end

  it "prevents deleting join rows" do
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Review labs",
      responsible: build_user(email: "responsible@example.test", role: :doctor)
    )
    tag = Tag.create!(name: "Call")
    task_tag = described_class.create!(task: task, tag: tag)

    expect(task_tag.destroy).to be(false)
    expect(task_tag.errors[:base]).to include("task tags must be deactivated instead of deleted")
    expect(described_class.find(task_tag.id)).to eq(task_tag)
  end

  it "prevents direct SQL join row deletes" do
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Review labs",
      responsible: build_user(email: "responsible@example.test", role: :doctor)
    )
    tag = Tag.create!(name: "Call")
    task_tag = described_class.create!(task: task, tag: tag)

    expect do
      described_class.transaction(requires_new: true) do
        described_class.connection.execute("DELETE FROM task_tags WHERE id = #{task_tag.id}")
      end
    end.to raise_error(ActiveRecord::StatementInvalid, /task tags must be deactivated instead of deleted/)
  end

  it "prevents direct SQL join row truncation" do
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Review labs",
      responsible: build_user(email: "responsible@example.test", role: :doctor)
    )
    tag = Tag.create!(name: "Call")
    described_class.create!(task: task, tag: tag)

    expect do
      described_class.transaction(requires_new: true) do
        described_class.connection.execute("TRUNCATE task_tags")
      end
    end.to raise_error(ActiveRecord::StatementInvalid, /task tags must be deactivated instead of deleted/)
  end

  def build_user(email:, role:)
    User.create!(
      email: email,
      password: "password123",
      role: role,
      name: email.split("@").first.capitalize,
      last_name: "User"
    )
  end
end
