# frozen_string_literal: true

OkComputer.mount_at = 'status'

OkComputer::Registry.register 'redis', OkComputer::RedisCheck.new(url: ENV.fetch('SIDEKIQ_REDIS_URL') { 'redis://localhost:6379/0' })

# check activestorage by uploading + downloading a file
class ActiveStorageCheck < OkComputer::Check
  def check
    service = ActiveStorage::Blob.service
    str = Time.now.to_i.to_s
    service.upload('.healthcheck', StringIO.new(str))
    service.download('.healthcheck') == str
  end
end
OkComputer::Registry.register 'activestorage', ActiveStorageCheck.new
