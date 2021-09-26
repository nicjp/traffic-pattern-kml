require 'conversions'
require 'bigdecimal'
require 'bigdecimal/util'

# Radius of Earth in Meters (from http://www.movable-type.co.uk/scripts/latlong.html)
EARTH_RADIUS = 6371e3

class Point
    attr_accessor :lat, :long, :name
    
    def initialize(lat = nil, long = nil, name = 'Point')
        @lat = lat
        @long = long
        @name = name
    end

    def to_s
        return "Lat: #{@lat}, Long: #{@long}"
    end
end

class Bearing
    attr_accessor :brng

    def initialize(brng = nil)
        @brng = brng
    end

    def turn(degrees)
        new_brng = @brng + degrees
        if new_brng >= 360
            new_brng = new_brng - 360
        end
        return Bearing.new(new_brng)
    end

    def to_s
        @brng.to_s
    end
end

# Calculate how much ground is covered in a climb for a given
# rate of climb and speed (to a given altitude)
# Returns length in nautical miles
def climb_descent_ground_distance(roc, speed, alt)
    climb_time = alt.to_d / roc.to_d
    climb_distance = (speed.to_d / 60) * climb_time
    alt_in_nm = Distance.new(alt, DistanceType::FOOT).inNauticalMiles
    ground_covered_sq = BigDecimal(climb_distance**2 - alt_in_nm **2)
    
    return ground_covered_sq.sqrt(2)
end

# Use magic constants to calculate rate of turn in degrees per second
# This forumula uses TAS, but for our purposes, IAS will do
def rate_of_turn(angle, speed)
    anglr = angle * Math::PI / 180
    rot = (1091 * Math::tan(anglr)) / speed
    rot
end

# Project the given source latitude and longitude by the given distance
# and bearing. 
# Distance: meters
# Bearing: degrees
# Forumla from: http://www.movable-type.co.uk/scripts/latlong.html
def project(lat, long, distance, bearing)
    # Convert lat and long to radians
    latr = lat * Math::PI / 180
    longr = long * Math::PI / 180
    brngr = bearing * Math::PI / 180

    dlatr = Math::asin( Math::sin(latr) * Math::cos(distance / EARTH_RADIUS) +
                Math::cos(latr) * Math::sin(distance / EARTH_RADIUS) * Math::cos(brngr) )
    dlongr = longr + Math::atan2( Math::sin(brngr) * Math::sin(distance / EARTH_RADIUS) * Math::cos(latr), 
                Math::cos(distance / EARTH_RADIUS) - Math::sin(latr) * Math::sin(dlatr) )
    
    # Normal destination longitude
    dlongrn = (dlongr + 540) % 360 - 180
    # Convert back to degrees
    dlat = dlatr * 180 / Math::PI
    dlong = dlongrn * 180 / Math::PI

    return Point.new(dlat, dlong)
end

# Calculate the distance between two points using the Haversine formula
# Formula from:  http://www.movable-type.co.uk/scripts/latlong.html
def distanceBetween(pointa, pointb)
    lat_ar = pointa.lat * Math::PI / 180
    lat_br = pointb.lat * Math::PI / 180
    lat_delta = (pointb.lat - pointa.lat) * Math::PI / 180
    lng_delta = (pointb.long - pointa.long) * Math::PI / 180

    halfchord = Math::sin(lat_delta / 2) * Math::sin(lat_delta / 2) + Math::cos(lat_ar) *
                    Math::cos(lat_br) * Math::sin(lng_delta / 2) * Math::sin(lng_delta / 2)
    angular_dist = 2 * Math::atan2(Math::sqrt(halfchord), Math::sqrt(1 - halfchord))

    return EARTH_RADIUS * angular_dist # distance in Meters
end