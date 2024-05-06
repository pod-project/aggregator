# frozen_string_literal: true

# AR model to store the JTI of active JWTs for resource access
class AllowlistedJwt < ApplicationRecord
  belongs_to :resource, polymorphic: true

  before_create :set_default_token_values

  def encoded_token
    @encoded_token ||= JWT.encode(jwt_attributes, Settings.jwt.secret, Settings.jwt.algorithm)
  end

  def jwt_attributes
    {
      jti:,
      scope:,
      iss: 'POD',
      name: label
    }.compact_blank
  end

  def last_used
    return unless updated_at
    return if created_at == updated_at

    updated_at
  end

  private

  def set_default_token_values
    self.jti ||= Digest::MD5.hexdigest([resource.to_global_id, Time.now.to_f].join(':'))
  end
end
