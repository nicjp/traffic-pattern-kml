#
#
require 'bigdecimal'

module DistanceType
    METER = 1
    FOOT = 2
    NM = 3
end

class Distance
    attr_reader :distance, :type

    def initialize(distance, type)
        @distance = BigDecimal(distance, 16)
        @type = type    
    end

    def inFeet
        case @type
        when DistanceType::METER
            @distance * 3.281
        when DistanceType::NM
            @distance * 6076
        when DistanceType::FOOT
            @distance
        end
    end

    def inMeters
        case @type
        when DistanceType::METER
            @distance
        when DistanceType::NM
          @distance * 1852
        when DistanceType::FOOT
            @distance * 0.3048
        end
    end

    def inNauticalMiles
        case @type
        when DistanceType::METER
            @distance / 1852
        when DistanceType::NM
            @distance
        when DistanceType::FOOT
            @distance / 6076
        end
    end

    def to_s
        @distance.to_s("F")
    end
end
