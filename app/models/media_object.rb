require 'securerandom'
require 'store_file'

class MediaObject < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper

  belongs_to :user
  belongs_to :project
  belongs_to :data_set
  belongs_to :tutorial
  belongs_to :visualization
  belongs_to :news, class_name: 'News', foreign_key: 'news_id'

  alias_attribute :title, :name

  validates_presence_of :media_type, :store_key
  validates :name, length: { maximum: 128 }

  validates_presence_of :name, :file

  before_save :sanitize_media
  before_save :check_store!

  after_destroy :remove_data!

  alias_attribute :owner, :user
  alias_attribute :dataSet, :data_set

  def parent
    project || data_set || tutorial || visualization || news || user
  end

  def sanitize_media
    self.title = sanitize title, tags: %w()
  end

  def check_store!
    if store_key.nil?
      self.store_key = store_make_key
    end

    store_make_uudir!(store_key)
  end

  def file_name
    uudir = store_uudir(store_key)
    "#{uudir}/#{file}"
  end

  def tn_file_name
    uudir = store_uudir(store_key)
    "#{uudir}/tn_#{file}"
  end

  def src
    return '' if store_key.nil? || file.nil?
    uupath = store_uupath(store_key)
    ename  = URI.escape(file)
    "#{uupath}/#{ename}"
  end

  def tn_src
    return '' if store_key.nil? || file.nil?
    uupath = store_uupath(store_key)
    ename  = URI.escape(file)
    "#{uupath}/tn_#{ename}"
  end

  def to_hash(recurse = true)
    h = {
      id: id,
      mediaType: media_type,
      name: name,
      url: UrlGenerator.new.media_object_url(self),
      createdAt: created_at.strftime('%B %d, %Y'),
      src: src,
      tn_src: tn_src
    }

    if recurse
      h.merge!(owner: owner.to_hash(false))

      if try(:project_id)
        h.merge!(project: project.to_hash(false))
      end

      if try(:data_set_id)
        h.merge!(dataSet: data_set.to_hash(false))
      end

      if try(:tutorial_id)
        h.merge!(tutorial: tutorial.to_hash(false))
      end

      if try(:visualization_id)
        h.merge!(visualization: visualization.to_hash(false))
      end

      if try(:news_id)
        h.merge!(news: news.to_hash(false))
      end
    end
    h
  end

  def add_tn
    if media_type == 'image'
      # make the thumbnail
      image = MiniMagick::Image.open(file_name)
      image.resize '180'

      # finish up
      File.open(tn_file_name, 'wb') do |oo|
        oo.write image.to_blob
      end

      File.chmod(0644, tn_file_name)

      self.save!
    end
  end

  # Creates a deep clone of a mediaobject, including copying the underlying file
  def cloneMedia
    nmo = dup
    nmo.store_key = nil
    nmo.check_store!
    FileUtils.cp(file_name, nmo.file_name)
    nmo.add_tn
    nmo.save!
    nmo
  end
  def summernote_image(params)
    puts "\n\n\n\n" + params[:upload_type] + "\n\n\n\n"
    self.id = Project.find(params[:proj_id]).media_objects
    self.project_id = params[:proj_id]
    self.media_type = 'image'
    self.name = "Uploaded-Image" + SecureRandom.hex[0...5] + ".jpg"
    self.created_at = Time.now.strftime('%B %d, %Y')
    imgFile = File.new("newfile.jpg", 'w')
    imgFile.write params[:image_data]
    puts imgFile
    #FileUtils.cp(imgFile, self.file)
    puts "self.src = ?\n"
    puts self.src
    self.store_key = nil
    self.check_store!
    self.sanitize_media
    #self.add_tn
    #self.save!
    puts "INSPECTING:\n\n\n\n" + self.inspect
  end
  private

  def remove_data!
    File.delete(file_name)
    File.delete(tn_file_name)
  rescue Errno::ENOENT
    # whatever
  end
  
end
