# frozen_string_literal: true

class NullOutClustersApplicationsRunnersVersion < ActiveRecord::Migration
  include Gitlab::Database::MigrationHelpers

  # Set this constant to true if this migration requires downtime.
  DOWNTIME = false

  disable_ddl_transaction!

  def up
    update_column_in_batches(:clusters_applications_runners, :version, nil)
  end

  def down
    # we cannot know the previous value for sure
  end
end
