class Place

	attr_accessor :id, :formatted_address, :location, :address_components

	def initialize(params= {})
		
		@id=params[:_id].to_s
		@formatted_address = params[:formatted_address]
		@location = Point.new(params[:geometry][:geolocation])
		if !params[:address_components].nil?
			@address_components = []
			params[:address_components].each do |r|
				@address_components.push(AddressComponent.new(r))
			end
		end
	end


	def self.mongo_client
		Mongoid::Clients.default
	end

	def self.collection
		mongo_client['places']
	end

	def self.load_all (file)
		
		data= JSON.parse(file.read)
		collection.insert_many(data)
	end

	def self.find_by_short_name (param)
		collection.find("address_components.short_name"=>param)
	end

	def self.to_places(params)
		places = []
		params.each do |r|
			places.push(Place.new(r))
		end
		
		return places
	end

	def self.find(id)
		place = Place.collection.find(:_id=>BSON::ObjectId.from_string(id)).first
		if !place.nil?
			return Place.new(place)
		end
	end

	def self.all(skip=0, limit=nil)
		places = self.collection.find.skip(skip)
		places = places.limit(limit) if !limit.nil?
		results=[]
		places.each do |r|
			results.push(Place.new(r))
		end
		return results
	end

	def destroy
		self.class.collection.find(:_id=>BSON::ObjectId.from_string(@id)).delete_one()
	end

	def self.get_address_components(sort=nil, skip=0, limit = nil)
		if sort.nil?
			sort = {:_id=>1 } 
		end
		if !limit.nil?
			return Place.collection.find.aggregate([{:$sort => sort},
										 {:$project => {:_id=> 1, :formatted_address=>1 , :address_components=>1, "geometry.geolocation":1}}, 
										 {:$unwind=> '$address_components'},
										 {:$skip =>skip}, 
										 {:$limit => limit } ])
		else
			return Place.collection.find.aggregate([{:$sort => sort},
										 {:$project => {:_id=> 1, :formatted_address=>1 , :address_components=>1,"geometry.geolocation":1}}, 
										 {:$skip =>skip},
										 {:$unwind=> '$address_components'} ])
		end

	end


	def self.get_country_names
		
		p = Place.collection.find.aggregate([{:$unwind => '$address_components'},
			{:$project => {:_id=>0, "address_components.long_name"=>1, "address_components.types"=>1} }, 
			{:$unwind => '$address_components.types'},
		 	{:$match=>{"address_components.types":'country'}},
		 	{:$group => {:_id=>"$address_components.long_name"}}])
	
		return p.to_a.map {|r| r[:_id]}
	end

	def self.find_ids_by_country_code (country_code)
		places = Place.collection.find.aggregate([ {:$unwind => "$address_components"},
										  {:$match => {"address_components.short_name":country_code}},
										  {:$project => {:_id=>1}} ])
		return places.map {|doc| doc[:_id].to_s}
	end

#--------------
	#Geolocation
	def self.create_indexes
		collection.indexes.create_one({"geometry.geolocation":Mongo::Index::GEO2DSPHERE})
	end

	def self.remove_indexes
		collection.indexes.drop_one("geometry.geolocation_2dsphere")
	end

	def self.near(point, max_meter=nil)
		my_point = Point.new(point.to_hash)
		return Place.collection.find("geometry.geolocation":{:$near => 
						 {:$geometry => {:type=>"Point", :coordinates=>[my_point.longitude, my_point.latitude] },
						  :$maxDistance=>max_meter}} )
	end

	def near(max_meter=nil)
		places=[]
		@latitude = @location.latitude
		@longitude = @location.longitude
		return self.class.to_places(self.class.collection.find("geometry.geolocation":{:$near => 
						 {:$geometry => {:type=>"Point", :coordinates=>[@longitude, @latitude] },
						  :$maxDistance=>max_meter}} ))
	end


end







									   
