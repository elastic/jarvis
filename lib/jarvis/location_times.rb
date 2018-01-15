require "time"
require "tzinfo"

module Jarvis
  class LocationTimes
    ZONES = {
      '     Berlin/Munich' => 'Europe/Berlin',
      '     London/Lisbon' => 'Europe/London',
      '   Montreal/Boston' => 'America/Montreal',
      'Minneapolis/Kansas' => 'America/Chicago',
      '     American Fork' => 'America/Denver',
      '     Mountain View' => 'America/Los_Angeles'
    }

    def initialize(utc = Time.now.utc)
      @utc = utc
      @zones = ZONES.inject({}){|m,(k,z)| m[k] = TZInfo::Timezone.get(z); m}
    end

    def to_a
      @zones.map do |k,tz|
        "#{k} #{tz.utc_to_local(@utc).strftime('%a %r')}"
      end
    end
  end
end
