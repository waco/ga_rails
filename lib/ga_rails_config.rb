# configuration
class GaRailsConfig
  @@mobile_account = nil
  def self.mobile_account=(value)
    @@mobile_account = value
  end
  def self.mobile_account
    raise RuntimeError, "must config ga_rails.mobile_account" if @@mobile_account.blank?
    @@mobile_account
  end
end

module GaRailsRailtie
  class Railtie < ::Rails::Railtie
    config.ga_rails = GaRailsConfig
    initializer "ga_rails.initialize" do |app|
    end
  end
end
