class SaveProjects < ActiveRecord::Migration
  def change
    Project.all.each do |p|
      p.save!
    end
  end
end
