require 'digest/md5'
require 'uri'
require 'net/http'

class GaTracker
  #Tracker version.
  GA_VERSION = "4.4sh"

  def initialize(url_params, request, cookie)
    @url_params = url_params
    @request = request
    @cookie = cookie
  end

  #Track a page view, updates all the cookies and campaign tracker,
  #makes a server side request to Google Analytics and writes the transparent
  #gif byte data to the response.
  def track_page_view
    time_stamp = Time.now.to_s
    domain_name = @request.server_name
    domain_name ||= ""

    #Get the referrer from the utmr parameter, this is the referrer to the
    #page that contains the tracking pixel, not the referrer for tracking
    #pixel.
    document_referer = @url_params["utmr"]
    if document_referer.blank? && document_referer != "0"
      document_referer = "-"
    else
      document_referer = CGI.unescape(document_referer)
    end

    document_path = @url_params["utmp"]
    document_path ||= ""
    document_path = CGI.unescape(document_path)

    account = @url_params["utmac"]
    user_agent = @request.user_agent
    user_agent ||= ""

    guid_header = @request.env["HTTP_X_DCMGUID"]
    guid_header ||= @request.env["HTTP_X_UP_SUBNO"]
    guid_header ||= @request.env["HTTP_X_JPHONE_UID"]
    guid_header ||= @request.env["HTTP_X_EM_UID"]

    visitor_id = get_visitor_id(guid_header, account, user_agent, @cookie)

    utm_gif_location = "http://www.google-analytics.com/__utm.gif"

    #Construct the gif hit url.
    utm_params = {
      "utmwv" => GA_VERSION,
      "utmn" => get_random_number,
      "utmhn" => CGI::escape(domain_name),
      "utmr" => CGI::escape(document_referer),
      "utmp" => CGI::escape(document_path),
      "utmac" => account,
      "utmcc" => "__utma%3D999.999.999.999.999.1%3B",
      "utmvid" => visitor_id,
      "utmip" => get_ip(@request.remote_addr)
    }
    utm_params["utmt"] = @url_params["utmt"] unless @url_params["utmt"].blank?
    utm_params["utme"] = @url_params["utme"] unless @url_params["utme"].blank?

    utm_url = utm_gif_location + "?" + utm_params.map{|k,v| "#{k}=#{v}"}.join("&")

    send_request_to_google_analytics(utm_url)

    return utm_url, time_stamp, visitor_id
  end

  #The last octect of the IP address is removed to anonymize the user.
  def get_ip(remote_address)
    return "" unless remote_address

    #Capture the first three octects of the IP address and replace the forth
    #with 0, e.g. 124.455.3.123 becomes 124.455.3.0
    regex = /^([^.]+\.[^.]+\.[^.]+\.).*/
    if matches = remote_address.scan(regex)
      return matches[0][0] + "0"
    else
      return ""
    end
  end

  private

  #Generate a visitor id for this hit.
  #If there is a visitor id in the cookie, use that, otherwise
  #use the guid if we have one, otherwise use a random number.
  def get_visitor_id(guid, account, user_agent, cookie)

    #If there is a value in the cookie, don't change it.
    return cookie unless cookie.blank?

    unless guid.blank?
      #Create the visitor id using the guid.
      message = "#{guid}#{account}"
    else
      #otherwise this is a new user, create a new random id.
      message = "#{user_agent}#{Digest::MD5.hexdigest(get_random_number)}"
    end

    md5_string = Digest::MD5.hexdigest(message)

    return "0x#{md5_string[0, 16]}"
  end

  #Get a random number string.
  def get_random_number()
    rand(0x7fffffff).to_s
  end

  #Make a tracking request to Google Analytics from this server.
  #Copies the headers from the original request to the new one.
  #If request containg utmdebug parameter, exceptions encountered
  #communicating with Google Analytics are thown.
  def send_request_to_google_analytics(utm_url)
    uri = URI.parse(utm_url)
    req = Net::HTTP::Get.new("#{uri.path}?#{uri.query}")
    req.add_field 'User-Agent', @request.user_agent.blank? ? "" : @request.user_agent
    req.add_field 'Accepts-Language', @request.accept_language.blank? ? "" : @request.accept_language
    res = Net::HTTP.new(uri.host, uri.port).start { |http| http.request(req) }

    warn res.body unless @url_params["utmdebug"].blank?
  end
end
