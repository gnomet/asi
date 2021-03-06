class ChangeGroupCreatedByToCreatorId < ActiveRecord::Migration
  def self.up
    drop_foreign_key :groups, :people
    rename_column :groups, :created_by, :creator_id
    foreign_key :groups, :creator_id, :people, :id
  end

  def self.down
    drop_foreign_key :groups, :people
    rename_column :groups, :creator_id, :created_by
    foreign_key :groups, :created_by, :people, :id
  end
  
  def self.foreign_key(from_table, from_column, to_table, to_column, suffix=nil, on_delete='SET NULL', on_update='CASCADE')
    constraint_name = "fk_#{from_table}_#{to_table}"
    constraint_name += "_#{suffix}" unless suffix.nil?
    execute %{alter table #{from_table}
     add constraint #{constraint_name}
     foreign key (#{from_column})
     references #{to_table}(#{to_column})
     on delete #{on_delete}
     on update #{on_update}
   }
  end

  def self.drop_foreign_key(from_table, to_table, suffix=nil)
    constraint_name = "fk_#{from_table}_#{to_table}"
    constraint_name += "_#{suffix}" unless suffix.nil?
    execute "alter table #{from_table} drop foreign key #{constraint_name}"
    execute "alter table #{from_table} drop key #{constraint_name}"
  end
end
