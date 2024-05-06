# frozen_string_literal: true

require_relative '../../spec/support/marc_fixture_seed_fetcher'

namespace :agg do
  desc 'Create an initial admin user'
  task create_admin: :environment do
    puts 'Creating an initial admin user.'
    u = prompt_to_create_user

    u.add_role(:admin)
    u.confirm
    puts 'User created.'
  end

  def prompt_to_create_user
    User.find_or_create_by!(email: prompt_for_email) do |u|
      puts 'User not found. Enter a password to create the user.'
      u.password = prompt_for_password
    end
  rescue StandardError => e
    puts e
    retry
  end

  def prompt_for_email
    print 'Email: '
    $stdin.gets.chomp
  end

  def prompt_for_password
    begin
      system 'stty -echo'
      print 'Password (must be 8+ characters): '
      password = $stdin.gets.chomp
      puts "\n"
    ensure
      system 'stty echo'
    end
    password
  end

  desc 'Seed data from Aggregator API'
  task seed_from_api: :environment do
    Upload.skip_callback(:commit, :after, :perform_extract_marc_record_metadata_job)

    puts "Seeding data from Aggregator @ #{Settings.marc_fixture_seeds.host} (this may take a several minutes)"
    Settings.marc_fixture_seeds.organizations.each do |org_name|
      puts "Fetching data from #{org_name}"
      organization = Organization.find_or_create_by(slug: org_name.downcase) do |org|
        org.name = org_name
      end

      stream = organization.streams.find_or_create_by(slug: 'seed_from_api')
      uploads = []

      total_file_count = 0
      MarcFixtureSeedFetcher.fetch_uploads(organization.slug) do |upload, files|
        upload_file_count = 0
        upload = stream.uploads.build(name: upload['name'])

        files.each do |file|
          puts "Uploading file #{file['filename']} (#{file['download_url']})"
          uri = URI.parse(file['download_url'])
          io = uri.open('Authorization' => "Bearer #{Settings.marc_fixture_seeds.token}")
          upload.files.attach(io:, filename: file['filename'])

          upload_file_count += 1
          break if upload_file_count >= Settings.marc_fixture_seeds.file_count
        end

        upload.save
        uploads << upload

        total_file_count += upload_file_count
        break if total_file_count >= Settings.marc_fixture_seeds.file_count
      end

      puts "Extracting metadata from #{total_file_count} files seeded from #{org_name}"
      # Run metadata extraction job serially
      uploads.each do |upload|
        ExtractMarcRecordMetadataJob.perform_now(upload)
      end

      stream.make_default
    end

    Upload.set_callback(:commit, :after, :perform_extract_marc_record_metadata_job)
  end
end
