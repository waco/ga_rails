module GaRailsHelper
  def ga_tag(ga_account, ga_rails_path)
    url = ""
    url << ga_rails_path + "?"
    url << "utmac=" + ga_account
    url << "&utmn=" + rand(0x7fffffff).to_s
    referer = ENV["HTTP_REFERER"]
    query = ENV["QUERY_STRING"]
    path = ENV["REQUEST_URI"]
    unless referer
      referer = "-"
    end
    url << "&utmr=" + CGI.escape(referer)
    if path
      url << "&utmp=" + CGI.escape(path)
    end
    url << "&guid=ON"

    url.gsub! "&", "&amp"

    raw %{<img src="#{url}" />}
  end
end
