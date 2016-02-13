class Point

	attr_accessor :longitude, :latitude

	def initialize(params ={})
		if !params[:lng].nil?
			@longitude = params[:lng]
		elsif !params[:coordinates].nil?
		 	@longitude = params[:coordinates][0]
		end
		
		if !params[:lng].nil?
			@latitude = params[:lat]
		elsif !params[:coordinates].nil?
		 	@latitude = params[:coordinates][1]
		end
	end

	def to_hash
		{"type":"Point", "coordinates":[@longitude, @latitude]}
	end
end