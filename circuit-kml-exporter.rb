#
#
require 'ruby_kml'
require 'pry'
require 'conversions'
require 'geo'

# Output KML Filename
OUTKML = 'test2.kml'

# Define Constants used to generate things
RWY_LENGTH      = 1335  # Runway length in meters
RWY_BEARING     = 344   # Runway bearing in degrees true
VARIATION       = 12    # Magentic variation  
PATTERN_HEIGHT  = 1000  # Height of pattern (AAL)
UPWIND_ROC      = 500   # Upwind Rate of Climb in ft/min
UPWIND_TH       = 600   # Height to turn Crosswind
UPWIND_SPEED    = 89    # Rate of Climb to pattern altitude
XWIND_BANK      = 15    # Xwind turn bank angle
XWIND_SPEED     = 110    # Xwind speed in knots(once PATTERN_HEIGHT achieved)
XWIND_DIST      = 0.8     # Crosswind distance in NM
DWIND_BANK      = 30    # Downwind turn bank angle
DWIND_SPEED     = 110    # Downwind speed in knots
BASE_SPEED      = 90    # Base speed in knots
BASE_BANK       = 30    # Base bank angle
BASE_DIST       = 1     
FINAL_BANK      = 20    # Final turn bank angle
FINAL_SPEED     = 80    # Final speed in knots
FINAL_ROD       = 500   # Rate of descent on final in ft/min
FINAL_HEIGHT    = 600   # Height to complete turn to final 

# The initial start point on the runway
START_POINT = Point.new(-37.974453, 145.099537)
END_POINT   = Point.new(-37.981993, 145.100244)

def calculate_xwind_turn_point(upwind_length, bearing)
    # Calculate upwind distance and then create new point
    xwind_turn_point = project(START_POINT.lat, START_POINT.long, upwind_length, bearing.brng)
    xwind_turn_point.name = 'XWind'

    xwind_turn_point
end

def calculate_downwind_turn_point(xwind_tp, bearing)
    # Calcuate the crosswing distance and project downwind turn point
    xwind_distance = Distance.new(XWIND_DIST, DistanceType::NM).inMeters
    downwind_turn_point = project(xwind_tp.lat, xwind_tp.long, xwind_distance, bearing.brng)
    downwind_turn_point.name = 'Downwind'

    downwind_turn_point
end

def calculate_base_turn_point(downwind_tp, downwind_length, bearing)
    base_turn_point = project(downwind_tp.lat, downwind_tp.long, downwind_length, bearing.brng)
    base_turn_point.name = 'Base'

    base_turn_point
end

def calculate_final_turn_point(base_tp, bearing)
    xwind_distance = Distance.new(BASE_DIST, DistanceType::NM).inMeters
    final_turn_point = project(base_tp.lat, base_tp.long, xwind_distance, bearing.brng)
    final_turn_point.name = 'Final'

    final_turn_point
end

def calculate_end_point(final_tp, final_length, bearing)
    end_point = project(final_tp.lat, final_tp.long, final_length, bearing.brng)
    end_point.name = 'End'

    end_point
end

def create_turn_points(turn_point, speed, bank, initial_bearing, final_bearing)
    rot = rate_of_turn(bank, speed)
    bearing_change = ((final_bearing.brng - initial_bearing.brng) % 180).abs
    turn_seconds = (bearing_change / rot).to_i
    mpers = Distance.new(speed.to_f / 3600, DistanceType::NM).inMeters
    
    points = []
    current_bearing = initial_bearing
    current_point = turn_point
    (1..turn_seconds).each do 
        next_bearing = current_bearing.turn(rot)
        next_point = project(current_point.lat, current_point.long, mpers, next_bearing.brng)

        points << next_point

        current_bearing = next_bearing
        current_point = next_point
    end

    points
end

def create_flightpath_points(output_summary = false)
    # Determine all bearings
    initial_bearing = Bearing.new(RWY_BEARING + VARIATION)
    xwind_bearing = initial_bearing.turn(90)
    downwind_bearing = xwind_bearing.turn(90)
    base_bearing = downwind_bearing.turn(90)
    final_bearing = base_bearing.turn(90)

    # Calculate leg distances (assume XWind and Base = 1Nm)
    upwind_length = Distance.new(climb_descent_ground_distance(UPWIND_ROC, UPWIND_SPEED, UPWIND_TH), DistanceType::NM)
    final_length = Distance.new(climb_descent_ground_distance(FINAL_ROD, FINAL_SPEED, FINAL_HEIGHT), DistanceType::NM)
    dwind_length = RWY_LENGTH + upwind_length.inMeters + final_length.inMeters

    points = [START_POINT]
    # Calculate upwind distance and then create new point
    xwind_tp = calculate_xwind_turn_point(upwind_length.inMeters, initial_bearing)
    points << xwind_tp

    xwind_turn = create_turn_points(xwind_tp, UPWIND_SPEED, XWIND_BANK, initial_bearing, xwind_bearing)
    points += xwind_turn

    dwind_tp = calculate_downwind_turn_point(xwind_turn[-1], xwind_bearing)
    points << dwind_tp

    dwind_turn = create_turn_points(dwind_tp, XWIND_SPEED, DWIND_BANK, xwind_bearing, downwind_bearing)
    points += dwind_turn

    base_tp = calculate_base_turn_point(dwind_turn[-1], dwind_length, downwind_bearing)
    points << base_tp

    base_turn = create_turn_points(base_tp, BASE_SPEED, BASE_BANK, downwind_bearing, base_bearing)
    points += base_turn

    final_tp = calculate_final_turn_point(base_turn[-1], base_bearing)
    points << final_tp

    final_turn = create_turn_points(final_tp, FINAL_SPEED, FINAL_BANK, base_bearing, final_bearing)
    points += final_turn

    points << END_POINT

    if output_summary
    end

    points
end

def to_coordinate_string(points)
    coord_string = ""
    points.each do |point|
        coord_string += "#{point.long},#{point.lat},1000\n"
    end
    coord_string
end

def generate_kml_file(coord_string)
    kml = KMLFile.new
    doc = KML::Document.new
    style = KML::Style.new(
        id: 'YellowLines',
        line_style: KML::LineStyle.new(color: '7f00ffff', width: 5),
        poly_style: KML::PolyStyle.new(color: '7f00ffff')
    )
    doc.styles = [style]
    linestring = KML::LineString.new(
        extrude: true,
        tessellate: true,
        altitude_mode: 'absolute',
        coordinates: coord_string
    )
    doc.features << KML::Placemark.new(
        style_url: '#YellowLines',
        geometry: linestring
    )
    kml.objects << doc

    # Output KML data to file
    begin
        out = File.open(OUTKML, 'w')
        out.write(kml.render)
    ensure
        out.close
    end
end


def main
    
    points = create_flightpath_points
    coord_string = to_coordinate_string(points)

    generate_kml_file(coord_string)
end

main