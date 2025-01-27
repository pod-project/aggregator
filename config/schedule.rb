# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Work-around for loading spring unless RAILS_ENV is actually defined...
job_type :runner,  "cd :path && RAILS_LOG_LEVEL=warn :environment_variable=:environment bin/rails runner -e :environment ':task' :output"

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# These jobs are expensive. Turning off this job for now
# so stats update only when new files are uploaded.
# every :day do
#   runner 'UpdateOrganizationStatisticsJob.perform_all'
# end

every 3.months do
  runner 'CleanupAndRemoveDataJob.enqueue_all'
end

# every :day do
#   runner 'GenerateDeltaDumpJob.enqueue_all'
# end
