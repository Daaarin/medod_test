# == Schema Information
#
# Table name: users
#
#  id                :bigint           not null, primary key
#  auth_token_digest :string
#  email             :string           not null
#  last_name         :string           not null
#  name              :string           not null
#  password_digest   :string           not null
#  password_salt     :string           not null
#  role              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_users_on_auth_token_digest   (auth_token_digest) UNIQUE
#  index_users_on_email               (email) UNIQUE
#  index_users_on_name_and_last_name  (name,last_name)
#
class User < ApplicationRecord
  PASSWORD_SALT_BYTES = 16
  PASSWORD_ITERATIONS = 120_000
  PASSWORD_DERIVED_KEY_LENGTH_BYTES = 32
  PASSWORD_DIGEST_ALGORITHM = "SHA256"
  ROLE_DISPLAY_NAMES = {
    administrator: "Администратор",
    doctor: "Врач",
    nurse: "Медсестра"
  }.freeze

  has_many :created_tasks, class_name: "Task", foreign_key: :creator_id, inverse_of: :creator, dependent: :restrict_with_exception
  has_many :responsible_tasks, class_name: "Task", foreign_key: :responsible_id, inverse_of: :responsible, dependent: :restrict_with_exception
  has_many :delegated_tasks, class_name: "Task", foreign_key: :delegated_user_id, inverse_of: :delegated_user, dependent: :restrict_with_exception

  enum :role, {
    administrator: "administrator",
    doctor: "doctor",
    nurse: "nurse"
  }, validate: true

  attr_reader :password

  validates :email, :role, :name, :last_name, presence: true
  validates :password_digest, :password_salt, presence: true
  validates :email, uniqueness: { case_sensitive: false }
  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  def display_name
    [ role_display_name, last_name, name ].compact.join(" ")
  end

  def role_display_name
    ROLE_DISPLAY_NAMES.fetch(role&.to_sym, role.to_s.humanize)
  end

  def password=(value)
    @password = value
    return if value.blank?

    self.password_salt = SecureRandom.hex(PASSWORD_SALT_BYTES)
    self.password_digest = self.class.digest_password(value, password_salt)
  end

  def authenticate(password)
    return false if password_digest.blank? || password_salt.blank?

    if ActiveSupport::SecurityUtils.secure_compare(self.class.digest_password(password, password_salt), password_digest)
      self
    else
      false
    end
  end

  def issue_auth_token!
    token = SecureRandom.urlsafe_base64(32)
    update!(auth_token_digest: self.class.digest_token(token))
    token
  end

  def self.authenticate_token(token)
    return nil if token.blank?

    find_by(auth_token_digest: digest_token(token))
  end

  def self.digest_token(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def self.digest_password(password, salt)
    OpenSSL::PKCS5.pbkdf2_hmac(
      password.to_s,
      salt.to_s,
      PASSWORD_ITERATIONS,
      PASSWORD_DERIVED_KEY_LENGTH_BYTES,
      PASSWORD_DIGEST_ALGORITHM
    ).unpack1("H*")
  end
end
