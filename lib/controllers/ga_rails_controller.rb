# Copyright 2009 Google Inc. All Rights Reserved.
require 'digest/md5'
require 'uri'
require 'net/http'

class GaRailsController < ApplicationController
  #Tracker version.
  GA_VERSION = "4.4sh"
  COOKIE_NAME = "__utmmobile"

  #The path the cookie will be available to, edit this to use a different
  #cookie path.
  COOKIE_PATH = "/"

  #Two years in seconds.
  COOKIE_USER_PERSISTENCE = 63072000

  #1x1 transparent GIF
  GIF_DATA = [
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61,
    0x01, 0x00, 0x01, 0x00, 0x80, 0xff,
    0x00, 0xff, 0xff, 0xff, 0x00, 0x00,
    0x00, 0x2c, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x01, 0x00, 0x00, 0x02,
    0x02, 0x44, 0x01, 0x00, 0x3b
  ]
  def index
    utm_url, time_stamp, visitor_id = track_page_view

    response.headers["Cache-Control"] = "private, no-cache, no-cache=Set-Cookie, proxy-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Wed, 17 Sep 1975 21:32:10 GMT"

    #If the debug parameter is on, add a header to the response that contains
    #the url that was used to contact Google Analytics.
    response.headers["X-GA-MOBILE-URL"] = utm_url unless params["utmdebug"].blank?

    #Always try and add the cookie to the response.
    response.headers["cookie"] = CGI::Cookie.new({
      "name" => COOKIE_NAME,
      "value" => visitor_id,
      "expire" => time_stamp + COOKIE_USER_PERSISTENCE.to_s,
      'path' => COOKIE_PATH
    })

    send_data GIF_DATA.pack("C35"), :disposition => 'inline', :type => 'image/gif'
  end

  private

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


  #Writes the bytes of a 1x1 transparent gif into the response.

  #Make a tracking request to Google Analytics from this server.
  #Copies the headers from the original request to the new one.
  #If request containg utmdebug parameter, exceptions encountered
  #communicating with Google Analytics are thown.
  def send_request_to_google_analytics(utm_url)
    uri = URI.parse(utm_url)
    req = Net::HTTP::Get.new("#{uri.path}?#{uri.query}")
    req.add_field 'User-Agent', request.user_agent.blank? ? "" : request.user_agent
    req.add_field 'Accepts-Language', request.accept_language.blank? ? "" : request.accept_language
    res = Net::HTTP.new(uri.host, uri.port).start { |http| http.request(req) }

    puts utm_url

    warn res.body unless params["utmdebug"].blank?
  end

  #Track a page view, updates all the cookies and campaign tracker,
  #makes a server side request to Google Analytics and writes the transparent
  #gif byte data to the response.
  def track_page_view
    time_stamp = Time.now.to_s
    domain_name = request.server_name
    domain_name ||= ""

    #Get the referrer from the utmr parameter, this is the referrer to the
    #page that contains the tracking pixel, not the referrer for tracking
    #pixel.
    document_referer = params["utmr"]
    if document_referer.blank? && document_referer != "0"
      document_referer = "-"
    else
      document_referer = CGI.unescape(document_referer)
    end

    document_path = params["utmp"]
    document_path ||= ""
    document_path = CGI.unescape(document_path)

    account = params["utmac"]
    user_agent = request.user_agent
    user_agent ||= ""

    #Try and get visitor cookie from the request.
    cookie = cookies[COOKIE_NAME]

    guid_header = request.env["HTTP_X_DCMGUID"]
    guid_header ||= request.env["HTTP_X_UP_SUBNO"]
    guid_header ||= request.env["HTTP_X_JPHONE_UID"]
    guid_header ||= request.env["HTTP_X_EM_UID"]

    visitor_id = get_visitor_id(guid_header, account, user_agent, cookie)

    utm_gif_location = "http://www.google-analytics.com/__utm.gif"

    #Construct the gif hit url.
    utm_url = [utm_gif_location, "?",
      "utmwv=", GA_VERSION,
      "&utmn=", get_random_number,
      "&utmhn=", CGI::escape(domain_name),
      "&utmr=", CGI::escape(document_referer),
      "&utmp=", CGI::escape(document_path),
      "&utmac=", account,
      "&utmcc=__utma%3D999.999.999.999.999.1%3B",
      "&utmvid=", visitor_id,
      "&utmip=", get_ip(request.remote_addr)
    ].join

    send_request_to_google_analytics(utm_url)

    return utm_url, time_stamp, visitor_id
  end
end
