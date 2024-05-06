# frozen_string_literal: true

class MarcFixtureSeedFetcher
  def self.fetch_uploads(slug, ...)
    new.fetch_uploads(slug, ...)
  end

  def fetch_uploads(slug, &)
    default_stream_url = default_stream_for(slug)['url']
    default_stream = JSON.parse(http_client.get(default_stream_url).body)

    default_stream['uploads']&.take(upload_count)&.each do |upload|
      yield upload, upload['files']
    end
  end

  private

  def http_client
    @http_client ||= HTTP.auth("Bearer #{token}")
  end

  def default_stream_for(slug)
    JSON.parse(
      http_client.get(
        "#{fixture_host}/organizations/#{slug}.json"
      ).body
    )['streams']&.find { |stream| stream['default'] }
  end

  def token
    Settings.marc_fixture_seeds.token
  end

  def fixture_host
    Settings.marc_fixture_seeds.host
  end

  def upload_count
    Settings.marc_fixture_seeds.upload_count
  end
end
