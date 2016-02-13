class Photo
	attr_accessor :id, :location, :contents


	def self.mongo_client
		Mongoid::Clients.default
	end

	def initialize(params={})
		Rails.logger.debug {"instantiating GridFsFile #{params}"}
		 if params[:_id]  #hash came from GridFS
		    @id=params[:_id].to_s
		    @location=params[:metadata].nil? ? nil : Point.new(params[:metadata][:location])
	    else              #assume hash came from Rails
	        @id=params[:id]
	        @location=params[:location]
	    end
  		@contents = params[:contents]
	end

	def persisted?
		!@id.nil?
	end

	def save
		description = {}
		description[:metadata]={}

		file=File.open(@contents,'rb')
		gps= EXIFR::JPEG.new(file).gps
		@location =Point.new(:lng=>gps.longitude, :lat=>gps.latitude)

		description[:content_type]= 'image/jpeg'
		description[:metadata][:location]=@location.to_hash 
		
		grid_file = Mongo::Grid::File.new(@contents.read, description)
		id=self.class.mongo_client.database.fs.insert_one(grid_file)
		@id=id.to_s
		return @id

	end

	def self.all(skip=0,limit=nil)
		photos = self.mongo_client.database.fs.find.skip(skip)
		photos = photos.limit(limit) if !limit.nil?
		return photos.find.map {|doc| Photo.new(doc) }
	end

	def self.find (id)
		f=mongo_client.database.fs.find(id_criteria(id)).first
    	return f.nil? ? nil : Photo.new(f)
	end

	def self.id_criteria id
	    {_id:BSON::ObjectId.from_string(id)}
	end

	def id_criteria
	    self.class.id_criteria @id
	end

	def contents
	    f=self.class.mongo_client.database.fs.find_one(id_criteria)
	    if f 
	      buffer = ""
	      f.chunks.reduce([]) do |x,chunk| 
	          buffer << chunk.data.data 
	      end
	      return buffer
	    end 
	end

	def destroy
	    self.class.mongo_client.database.fs.find(id_criteria).delete_one
	end


	#Relationships
end






