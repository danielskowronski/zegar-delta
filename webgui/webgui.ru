class ZegarDeltaWebgui
  def alarmsConfig(req)
    fileIndex  = File.open(File.dirname(__FILE__)+"/index.html", "rb")
    fileAlarms = File.open(File.dirname(__FILE__)+"/../minion/alarms.json", "rb")
    contentsIndex = fileIndex.read
    contentsAlarms = fileAlarms.read
    contentsIndex.sub! "{REPLACE_ME}",   contentsAlarms
    contentsIndex
  end

  def validateJson(input)
    begin
      alarms = JSON.parse(input)

      alarms["regular"].each do |alarm|
        if (alarm["dow"] =~ /[01234567]{0,7}/).nil? then raise "error" end
        if (alarm["time"] =~ /([01]?[0-9]|2[0-3]):[0-5][0-9]/).nil? then raise "error" end
      end
      alarms["special"].each do |alarm|
        if (alarm["date"] =~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/).nil? then raise "error" end
        if (alarm["time"] =~ /([01]?[0-9]|2[0-3]):[0-5][0-9]/).nil? then raise "error" end
      end
      alarms["exceptions"].each do |alarm|
        if (alarm["date"] =~ /[0-9]{4}-[0-9]{2}-[0-9]{2}/).nil? then raise "error" end
        if (alarm["time"] =~ /([01]?[0-9]|2[0-3]):[0-5][0-9]/).nil? then raise "error" end
      end

    rescue
      return false
    end

    return true
  end

  def alarmsConfigPost(req)
    if !req.post? then '{"state":"error", "msg":"transport"}' end
    json = req.params["data"]
    if validateJson(json)
      '{"state":"error", "msg":"validation"}'
    else
      File.open(File.dirname(__FILE__)+"/../minion/alarms.json", 'w') { |file| file.write(json) }
      '{"state":"success"}'
    end

  end

  def call(env)
    req = Rack::Request.new(env)
    case req.path_info
    when "/"
      [200, {"Content-Type" => "text/html"}, [alarmsConfig(req)]]
    when "/alarms/post"
      [200, {"Content-Type" => "application/json"}, [alarmsConfigPost(req)]]
    else
      [404, {"Content-Type" => "text/html"}, ["HTTP/404"]]
    end
  end
end

run ZegarDeltaWebgui.new
