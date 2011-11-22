module GaRailsHelper
  # GoogleAnalyticsトラッキングコードの携帯版のimgタグを出力する
  # ga_account:String アカウントID
  # ga_rails_path:String GaRailsController#indexまでのパス
  def ga_tag(ga_account, ga_rails_path)
    url = ""
    url << ga_rails_path + "?"
    url << "utmac=" + ga_account
    url << "&utmn=" + rand(0x7fffffff).to_s
    referer = request.referer
    query = request.query_string
    path = request.request_uri

    referer = "-" if referer.blank?
    url << "&utmr=" + CGI.escape(referer)
    url << "&utmp=" + CGI.escape(path) unless path.blank?
    url << "&guid=ON"

    url.gsub! "&", "&amp;"

    raw %{<img src="#{url}" />}
  end
end
