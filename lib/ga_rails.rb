module GaRails
  COOKIE_NAME = "__utmmobile"

  #The path the cookie will be available to, edit this to use a different
  #cookie path.
  COOKIE_PATH = "/"

  #Two years in seconds.
  COOKIE_USER_PERSISTENCE = 63072000

  private

  def track_ga_rails(options = {})
    url_params = {}
    url_params["utmac"] = GaRailsConfig.mobile_account
    url_params["utmn"] = rand(0x7fffffff).to_s
    unless options[:event].blank?
      url_params["utmt"] = "event"
      options[:event] = options[:event].join('*') if options[:event].is_a? Array
      url_params["utme"] = "5(#{CGI.escape options[:event].to_s})"
    end
    referer = request.referer
    query = request.query_string
    path = request.fullpath

    referer = "-" if referer.blank?
    url_params["utmr"] = CGI.escape(referer)
    url_params["utmp"] = CGI.escape(path)
    url_params["guid"] = "ON"

    ga_rails = GaTracker.new(url_params, request, cookies[COOKIE_NAME])
    utm_url, time_stamp, visitor_id = ga_rails.track_page_view

    #Always try and add the cookie to the response.
    cookies[COOKIE_NAME] = {
      "value" => visitor_id,
      "expire" => time_stamp + COOKIE_USER_PERSISTENCE.to_s,
      'path' => COOKIE_PATH
    }
  end
end
