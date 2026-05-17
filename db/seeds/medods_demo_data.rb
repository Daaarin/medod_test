# frozen_string_literal: true

require "faker" unless defined?(Rails) && Rails.env.production?

module MedodsDemoData
  class Runner
    DEFAULT_PASSWORD = "Password123!"
    SEED = 20_260_517

    SYSTEM_TAG_NAMES = [
      "Отчётность",
      "Операции",
      "Звонок"
    ].freeze

    COMMON_TAG_NAMES = [
      "Обход",
      "Документы",
      "Анализы",
      "Инвентаризация",
      "Логистика",
      "Консилиум"
    ].freeze

    def self.call
      new.call
    end

    def initialize
      Faker::Config.random = Random.new(SEED)
      srand(SEED)
    end

    def call
      users = seed_users
      tags = seed_tags

      seed_tasks(users, tags)
    end

    private

      def seed_users
        {
          administrator: seed_user(role: "administrator", email: "admin.demo@medods.local"),
          doctors: Array.new(3) do |index|
            seed_user(role: "doctor", email: "doctor.#{index + 1}.demo@medods.local")
          end,
          nurses: Array.new(3) do |index|
            seed_user(role: "nurse", email: "nurse.#{index + 1}.demo@medods.local")
          end
        }
      end

      def seed_user(role:, email:)
        user = User.find_or_initialize_by(email: email)
        user.assign_attributes(
          role: role,
          name: Faker::Name.first_name,
          last_name: Faker::Name.last_name
        )
        user.password = DEFAULT_PASSWORD if user.new_record?
        user.save!
        user
      end

      def seed_tags
        {
          system: SYSTEM_TAG_NAMES.index_with { |name| seed_system_tag(name) },
          common: COMMON_TAG_NAMES.index_with { |name| seed_common_tag(name) }
        }
      end

      def seed_system_tag(name)
        tag = Tag.find_or_initialize_by(name: name)

        if tag.new_record?
          tag.is_system_tag = true
          tag.deactivated_at = nil
          tag.save!
        elsif !tag.system_tag?
          tag.update!(is_system_tag: true, deactivated_at: nil)
        end

        tag
      end

      def seed_common_tag(name)
        tag = Tag.find_or_initialize_by(name: name)
        tag.description = Faker::Lorem.sentence(word_count: 8)
        tag.save!
        tag
      end

      def seed_tasks(users, tags)
        today = Date.current

        task_specs(users, tags, today).each do |spec|
          seed_task(spec)
        end
      end

      def task_specs(users, tags, today)
        doctor_1 = users.fetch(:doctors).first
        doctor_2 = users.fetch(:doctors)[1]
        doctor_3 = users.fetch(:doctors)[2]
        nurse_1 = users.fetch(:nurses).first
        nurse_2 = users.fetch(:nurses)[1]
        nurse_3 = users.fetch(:nurses)[2]
        admin = users.fetch(:administrator)

        [
          {
            name: "Утренний обход отделения",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "one_time",
            status: "ongoing",
            creator: admin,
            responsible: doctor_1,
            first_run_at: time_on(today - 1.day, 8, 30),
            next_run_at: time_on(today, 8, 30),
            tags: [ tags.dig(:system, "Звонок"), tags.dig(:common, "Обход") ],
            occurrences: [
              {
                scheduled_at: time_on(today - 1.day, 8, 30),
                status: "executed",
                actual_at: time_on(today - 1.day, 8, 42),
                generated_at: time_on(today - 1.day, 7, 55)
              },
              {
                scheduled_at: time_on(today, 8, 30),
                status: "planned",
                generated_at: time_on(today - 1.day, 7, 55)
              }
            ],
            events: [
              {
                event_type: "created",
                actor: admin,
                occurred_at: time_on(today - 1.day, 7, 50)
              },
              {
                event_type: "accepted",
                actor: doctor_1,
                occurred_at: time_on(today - 1.day, 8, 5)
              }
            ]
          },
          {
            name: "Обзвон пациентов после выписки",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "one_time",
            status: "pending_acceptance",
            creator: doctor_2,
            delegated_user: nurse_1,
            first_run_at: time_on(today, 11, 0),
            next_run_at: time_on(today, 11, 0),
            tags: [ tags.dig(:system, "Звонок"), tags.dig(:common, "Документы") ],
            occurrences: [
              {
                scheduled_at: time_on(today, 11, 0),
                status: "planned",
                generated_at: time_on(today - 1.day, 18, 10)
              }
            ],
            events: [
              {
                event_type: "created",
                actor: doctor_2,
                occurred_at: time_on(today - 1.day, 18, 0)
              }
            ]
          },
          {
            name: "Подготовка операционного листа",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "one_time",
            status: "draft",
            creator: doctor_1,
            responsible: doctor_1,
            first_run_at: time_on(today + 1.day, 14, 0),
            next_run_at: time_on(today + 1.day, 14, 0),
            tags: [ tags.dig(:system, "Операции"), tags.dig(:common, "Документы") ],
            events: [
              {
                event_type: "created",
                actor: doctor_1,
                occurred_at: time_on(today - 2.days, 15, 0)
              }
            ]
          },
          {
            name: "Сводка по выписанным пациентам",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "one_time",
            status: "completed",
            creator: nurse_2,
            responsible: doctor_2,
            first_run_at: time_on(today - 3.days, 16, 0),
            next_run_at: time_on(today - 3.days, 16, 0),
            completion_date: today - 2.days,
            completed_at: time_on(today - 2.days, 16, 25),
            end_reason: "series_completed",
            tags: [ tags.dig(:system, "Отчётность"), tags.dig(:common, "Документы") ],
            occurrences: [
              {
                scheduled_at: time_on(today - 3.days, 16, 0),
                status: "executed",
                actual_at: time_on(today - 3.days, 16, 18),
                generated_at: time_on(today - 3.days, 8, 0)
              }
            ],
            events: [
              {
                event_type: "created",
                actor: nurse_2,
                occurred_at: time_on(today - 3.days, 8, 0)
              },
              {
                event_type: "completed",
                actor: doctor_2,
                occurred_at: time_on(today - 2.days, 16, 25)
              }
            ]
          },
          {
            name: "Контроль стерильности перевязочной",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "one_time",
            status: "cancelled",
            creator: doctor_3,
            responsible: nurse_3,
            first_run_at: time_on(today - 1.day, 12, 15),
            next_run_at: time_on(today - 1.day, 12, 15),
            cancelled_at: time_on(today - 1.day, 11, 45),
            cancellation_reason: "equipment check failed",
            end_reason: "manual_cancelled",
            tags: [ tags.dig(:common, "Анализы"), tags.dig(:common, "Инвентаризация") ],
            occurrences: [
              {
                scheduled_at: time_on(today - 1.day, 12, 15),
                status: "cancelled",
                skip_reason: "equipment check failed",
                generated_at: time_on(today - 1.day, 9, 30)
              }
            ],
            events: [
              {
                event_type: "created",
                actor: doctor_3,
                occurred_at: time_on(today - 1.day, 9, 20)
              },
              {
                event_type: "cancelled",
                actor: nurse_3,
                occurred_at: time_on(today - 1.day, 11, 45)
              }
            ]
          },
          {
            name: "Ежедневный обзвон пациентов",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "recurring",
            status: "ongoing",
            creator: admin,
            responsible: nurse_1,
            first_run_at: time_on(today - 7.days, 9, 0),
            next_run_at: time_on(today, 9, 0),
            tags: [ tags.dig(:system, "Звонок"), tags.dig(:common, "Консилиум") ],
            recurrence_rule: {
              rule_type: "every_n_days",
              interval_value: 1,
              execution_time: clock_time(9, 0),
              timezone: Time.zone.tzinfo.name,
              date_start: today - 7.days,
              date_end: today + 21.days
            },
            occurrences: [
              {
                scheduled_at: time_on(today - 1.day, 9, 0),
                status: "executed",
                actual_at: time_on(today - 1.day, 9, 12),
                generated_at: time_on(today - 7.days, 9, 0)
              },
              {
                scheduled_at: time_on(today, 9, 0),
                status: "planned",
                generated_at: time_on(today - 7.days, 9, 0)
              }
            ],
            events: [
              {
                event_type: "created",
                actor: admin,
                occurred_at: time_on(today - 7.days, 8, 45)
              },
              {
                event_type: "accepted",
                actor: nurse_1,
                occurred_at: time_on(today - 7.days, 8, 55)
              }
            ]
          },
          {
            name: "Месячная отчетность",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "recurring",
            status: "ongoing",
            creator: doctor_2,
            responsible: nurse_2,
            first_run_at: time_on(today - 2.months, 17, 0),
            next_run_at: time_on(today + 5.days, 17, 0),
            tags: [ tags.dig(:system, "Отчётность"), tags.dig(:common, "Документы") ],
            recurrence_rule: {
              rule_type: "every_n_months",
              interval_value: 1,
              day_of_month: 5,
              execution_time: clock_time(17, 0),
              timezone: Time.zone.tzinfo.name,
              date_start: today - 2.months,
              date_end: today + 4.months
            },
            occurrences: [
              {
                scheduled_at: time_on(today - 1.month, 17, 0),
                status: "executed",
                actual_at: time_on(today - 1.month, 17, 20),
                generated_at: time_on(today - 2.months, 17, 0)
              },
              {
                scheduled_at: time_on(today + 5.days, 17, 0),
                status: "planned",
                generated_at: time_on(today - 2.months, 17, 0)
              }
            ],
            events: [
              {
                event_type: "created",
                actor: doctor_2,
                occurred_at: time_on(today - 2.months, 10, 0)
              }
            ]
          },
          {
            name: "Годовой аудит оборудования",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "recurring",
            status: "ongoing",
            creator: doctor_3,
            responsible: doctor_3,
            first_run_at: time_on(today - 1.year, 10, 0),
            next_run_at: time_on(today + 2.months, 10, 0),
            tags: [ tags.dig(:system, "Отчётность"), tags.dig(:common, "Инвентаризация") ],
            recurrence_rule: {
              rule_type: "every_n_years",
              interval_value: 1,
              month_of_year: 5,
              day_of_month: 17,
              execution_time: clock_time(10, 0),
              timezone: Time.zone.tzinfo.name,
              date_start: today - 1.year,
              date_end: today + 2.years
            },
            occurrences: [
              {
                scheduled_at: time_on(today + 2.months, 10, 0),
                status: "planned",
                generated_at: time_on(today - 1.year, 10, 0)
              }
            ],
            events: [
              {
                event_type: "created",
                actor: doctor_3,
                occurred_at: time_on(today - 1.year, 9, 50)
              }
            ]
          },
          {
            name: "Четный день инвентаризации",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "recurring",
            status: "ongoing",
            creator: nurse_1,
            responsible: nurse_2,
            first_run_at: time_on(today - 10.days, 13, 0),
            next_run_at: time_on(today + 2.days, 13, 0),
            tags: [ tags.dig(:common, "Инвентаризация"), tags.dig(:common, "Логистика") ],
            recurrence_rule: {
              rule_type: "day_of_month_parity",
              day_of_month_parity: "even",
              execution_time: clock_time(13, 0),
              timezone: Time.zone.tzinfo.name,
              date_start: today - 10.days,
              date_end: today + 30.days
            },
            occurrences: [
              {
                scheduled_at: time_on(today + 2.days, 13, 0),
                status: "planned",
                generated_at: time_on(today - 10.days, 13, 0)
              }
            ],
            events: [
              {
                event_type: "created",
                actor: nurse_1,
                occurred_at: time_on(today - 10.days, 12, 45)
              }
            ]
          },
          {
            name: "Нечетные дни связи с отделениями",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "recurring",
            status: "ongoing",
            creator: admin,
            responsible: doctor_1,
            delegated_user: nurse_3,
            first_run_at: time_on(today - 14.days, 15, 30),
            next_run_at: time_on(today + 1.day, 15, 30),
            tags: [ tags.dig(:system, "Звонок"), tags.dig(:common, "Консилиум") ],
            recurrence_rule: {
              rule_type: "weekday_parity",
              weekday_parity: "odd",
              execution_time: clock_time(15, 30),
              timezone: Time.zone.tzinfo.name,
              date_start: today - 14.days,
              date_end: today + 21.days
            },
            occurrences: [
              {
                scheduled_at: time_on(today + 1.day, 15, 30),
                status: "planned",
                generated_at: time_on(today - 14.days, 15, 30)
              }
            ],
            events: [
              {
                event_type: "created",
                actor: admin,
                occurred_at: time_on(today - 14.days, 15, 15)
              }
            ]
          },
          {
            name: "Вакцинация по специальным датам",
            description: Faker::Lorem.paragraph(sentence_count: 2),
            task_kind: "recurring",
            status: "completed",
            creator: doctor_2,
            responsible: nurse_3,
            first_run_at: time_on(today - 6.days, 9, 15),
            next_run_at: time_on(today - 2.days, 9, 15),
            completion_date: today - 2.days,
            completed_at: time_on(today - 2.days, 9, 25),
            end_reason: "series_completed",
            tags: [ tags.dig(:common, "Анализы"), tags.dig(:common, "Документы") ],
            recurrence_rule: {
              rule_type: "specific_dates",
              execution_time: clock_time(9, 15),
              timezone: Time.zone.tzinfo.name,
              date_start: today - 6.days,
              date_end: today - 1.day,
              dates: [ today - 6.days, today - 4.days, today - 2.days ]
            },
            occurrences: [
              {
                scheduled_at: time_on(today - 6.days, 9, 15),
                status: "executed",
                actual_at: time_on(today - 6.days, 9, 28),
                generated_at: time_on(today - 6.days, 9, 0)
              },
              {
                scheduled_at: time_on(today - 4.days, 9, 15),
                status: "executed",
                actual_at: time_on(today - 4.days, 9, 21),
                generated_at: time_on(today - 4.days, 9, 0)
              },
              {
                scheduled_at: time_on(today - 2.days, 9, 15),
                status: "executed",
                actual_at: time_on(today - 2.days, 9, 20),
                generated_at: time_on(today - 2.days, 9, 0)
              }
            ],
            events: [
              {
                event_type: "created",
                actor: doctor_2,
                occurred_at: time_on(today - 6.days, 8, 50)
              },
              {
                event_type: "completed",
                actor: nurse_3,
                occurred_at: time_on(today - 2.days, 9, 25)
              }
            ]
          }
        ]
      end

      def seed_task(spec)
        task = Task.find_or_initialize_by(name: spec.fetch(:name))

        if task.new_record?
          task.assign_attributes(
            description: spec[:description],
            task_kind: spec[:task_kind],
            status: spec[:status],
            creator: spec[:creator],
            responsible: spec[:responsible],
            delegated_user: spec[:delegated_user],
            first_run_at: spec[:first_run_at],
            next_run_at: spec[:next_run_at],
            completion_date: spec[:completion_date],
            completed_at: spec[:completed_at],
            cancelled_at: spec[:cancelled_at],
            cancellation_reason: spec[:cancellation_reason],
            end_reason: spec[:end_reason]
          )
          task.save!
        end

        Array(spec[:tags]).compact.each do |tag|
          TaskTag.attach!(task: task, tag: tag)
        end

        seed_recurrence_rule(task, spec[:recurrence_rule]) if spec[:recurrence_rule]
        seed_occurrences(task, spec[:occurrences]) if spec[:occurrences]
        seed_events(task, spec[:events]) if spec[:events]

        task
      end

      def seed_recurrence_rule(task, spec)
        rule = task.recurrence_rule || task.build_recurrence_rule
        dates = Array(spec[:dates]).compact

        rule.assign_attributes(spec.except(:dates))
        dates.each do |date|
          rule.recurrence_rule_dates.find_or_initialize_by(run_date: date)
        end
        rule.save!
        rule
      end

      def seed_occurrences(task, specs)
        Array(specs).each do |occurrence_spec|
          task.task_occurrences.find_or_create_by!(
            scheduled_at: occurrence_spec.fetch(:scheduled_at),
            status: occurrence_spec.fetch(:status)
          ) do |occurrence|
            occurrence.actual_at = occurrence_spec[:actual_at]
            occurrence.postponed_to = occurrence_spec[:postponed_to]
            occurrence.skip_reason = occurrence_spec[:skip_reason]
            occurrence.generated_at = occurrence_spec[:generated_at]
          end
        end
      end

      def seed_events(task, specs)
        Array(specs).each do |event_spec|
          actor = event_spec.fetch(:actor)
          occurrence = event_spec[:occurrence]

          task.task_events.find_or_create_by!(
            event_type: event_spec.fetch(:event_type),
            actor_id: actor.id,
            occurred_at: event_spec.fetch(:occurred_at),
            occurrence_id: occurrence&.id
          ) do |event|
            event.payload_json = event_spec.fetch(:payload_json, {})
          end
        end
      end

      def time_on(date, hour, minute = 0)
        Time.zone.local(date.year, date.month, date.day, hour, minute, 0)
      end

      def clock_time(hour, minute = 0)
        Time.zone.local(2000, 1, 1, hour, minute, 0)
      end
  end
end
