require "rails_helper"

RSpec.describe Tag, type: :model do
  it "validates basic tag fields and soft deactivates non-system tags" do
    tag = described_class.create!(name: "Process", description: "Operational tag")

    expect(tag).to be_active

    tag.deactivate!

    expect(tag.reload.deactivated_at).to be_present
    expect(tag).not_to be_active
  end

  it "prevents non-system tags from being deleted" do
    tag = described_class.create!(name: "Custom")

    expect(tag.destroy).to be(false)
    expect(tag.errors[:base]).to include("tags must be deactivated instead of deleted")
    expect(described_class.find(tag.id)).to eq(tag)
  end

  it "prevents system tags from being renamed, deactivated, or deleted" do
    tag = described_class.create!(name: "Отчётность", is_system_tag: true)

    expect(tag.update(name: "Updated")).to be(false)
    expect(tag.errors[:base]).to include("system tags cannot be renamed, deactivated, or deleted")

    expect(tag.update(deactivated_at: Time.current)).to be(false)
    expect(tag.errors[:base]).to include("system tags cannot be renamed, deactivated, or deleted")

    expect(tag.destroy).to be(false)
    expect(tag.errors[:base]).to include("tags must be deactivated instead of deleted")
  end

  it "prevents direct SQL updates to system tags" do
    tag = described_class.create!(name: "Операции", is_system_tag: true)

    expect do
      described_class.transaction(requires_new: true) do
        described_class.connection.execute("UPDATE tags SET name = 'Blocked' WHERE id = #{tag.id}")
      end
    end.to raise_error(ActiveRecord::StatementInvalid, /system tags cannot be updated or deleted/)
  end

  it "prevents direct SQL tag deletes" do
    tag = described_class.create!(name: "Custom")

    expect do
      described_class.transaction(requires_new: true) do
        described_class.connection.execute("DELETE FROM tags WHERE id = #{tag.id}")
      end
    end.to raise_error(ActiveRecord::StatementInvalid, /tags must be deactivated instead of deleted/)
  end

  it "prevents direct SQL tag truncation" do
    described_class.create!(name: "Custom")

    expect do
      described_class.transaction(requires_new: true) do
        described_class.connection.execute("TRUNCATE tags CASCADE")
      end
    end.to raise_error(ActiveRecord::StatementInvalid, /tags must be deactivated instead of deleted/)
  end

  it "deactivates active task tag joins when a tag is deactivated" do
    user = User.create!(
      email: "responsible@example.test",
      password: "password123",
      role: :doctor,
      name: "Responsible",
      last_name: "User"
    )
    task = Task.create!(task_kind: :one_time, status: :ongoing, name: "Review labs", responsible: user)
    tag = described_class.create!(name: "Process")
    task_tag = TaskTag.create!(task: task, tag: tag)

    tag.deactivate!

    expect(task_tag.reload.deactivated_at).to be_present
  end
end
