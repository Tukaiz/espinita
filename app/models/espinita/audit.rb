module Espinita
  class Audit < ActiveRecord::Base
    belongs_to :auditable, polymorphic: true
    belongs_to :user, polymorphic: true


    scope :descending,    ->{ reorder(version: :desc)}
    scope :creates,       ->{ where({:action => 'create'})}
    scope :updates,       ->{ where({:action => 'update'})}
    scope :destroys,      ->{ where({:action => 'destroy'})}

    scope :up_until,      ->(date_or_time){where("created_at <= ?", date_or_time) }
    scope :from_version,  ->(version){where(['version >= ?', version]) }
    scope :to_version,    ->(version){where(['version <= ?', version]) }
    scope :auditable_finder, ->(auditable_id, auditable_type){where(auditable_id: auditable_id, auditable_type: auditable_type)}

    serialize :audited_changes

    before_create :set_version_number, :set_audit_user

    # Return all audits older than the current one.
    def ancestors
      table = self.class.arel_table
      self.class.where(table[:auditable_id].eq(auditable_id).and(table[:auditable_type].eq(auditable_type)).and(table[:version].lteq(version)))
    end

    # Return all audits newer than current one (used for rollback)
    def descendants
      table = self.class.arel_table
      self.class.where(table[:auditable_id].eq(auditable_id).and(table[:auditable_type].eq(auditable_type)).and(table[:version].gteq(version)))
    end

  private
    def set_version_number
      max = self.class.auditable_finder(auditable_id, auditable_type).maximum(:version) || 0
      self.version = max + 1
    end

    def set_audit_user
      self.user           = RequestStore.store[:audited_user] if RequestStore.store[:audited_user]
      self.remote_address = RequestStore.store[:audited_ip]   if RequestStore.store[:audited_ip]

      nil # prevent stopping callback chains
    end

  end
end
