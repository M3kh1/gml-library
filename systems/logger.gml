
function Logger(_name="Logger", _showLog=true) constructor
{
    name = _name;
    logs = [];
    showLog = _showLog;
    showTags = []; // empty = show all
	excludeTags = false; // false should filter only for the selected tags, true do the opposite
    showTimeStamp = false;
	
    
    function LogData(_msg, _tag) constructor
    {
        timeStamp = $"[{current_hour}:{current_minute}:{current_second}]";
        msg = _msg;
        tag = _tag;
		//exclude = false;
    }
    
	
	setShowTimeStamp = function(_bool)
	{
		showTimeStamp = _bool;
	}

	setTagFilter = function(_tags=[], _exclude=false)
	{
	    showTags = _tags; // empty array = show all
		excludeTags = _exclude;
	}
	
	#region > Log Functions
	
	log = function(_tag, _msg, _exclude=false)
	{
	    var _logEntry = new LogData(_msg, _tag);
	    array_push(logs, _logEntry);

	    var _finalMsg = $"[{name}][{_tag}] ~ {_msg}";
	    if showTimeStamp _finalMsg = _logEntry.timeStamp + _finalMsg;

	    if showLog
	    {
	        if (array_length(showTags) == 0)
	        {
	            // No filtering, show everything
	            if (_exclude != true) show_debug_message(_finalMsg);
	        }
	        else if (excludeTags)
	        {
	            // Blacklist mode
	            if (!array_contains(showTags, _tag)) show_debug_message(_finalMsg);
	        }
	        else
	        {
	            // Whitelist mode
	            if (array_contains(showTags, _tag)) show_debug_message(_finalMsg);
	        }
	    }
	}
    
	
	// Base tags
    logInfo = function(_msg, _exclude=false) { log("info", _msg, _exclude); }
    logDebug = function(_msg, _exclude=false) { log("debug", _msg, _exclude); }
    logWarning = function(_msg, _exclude=false) { log("warning", _msg, _exclude); }
    logError = function(_msg, _exclude=false) { log("error", _msg, _exclude); }
    logProfile = function(_msg, _exclude=false) { log("profile", _msg, _exclude); }
    
	// --- Print all stored logs for a specific tag ---
	printLog = function(_tag)
	{
	    for (var i = 0; i < array_length(logs); i++)
	    {
	        var _entry = logs[i];
	        if ((excludeTags && !array_contains(showTags, _entry.tag)) || (!excludeTags && array_length(showTags) == 0)
			|| (!excludeTags && array_contains(showTags, _entry.tag)) ||  _entry.tag == _tag) // always print specific tag requested
	        {
	            var _finalMsg = $"[{name} | {_entry.tag}] ~ {_entry.msg}";
	            if (showTimeStamp) _finalMsg = _entry.timeStamp + _finalMsg;
	            show_debug_message(_finalMsg);
	        }
	    }
	}
	
	#endregion

    
	// Custom function profiler
    doProfile = function(_tag, _func, _args=[])
    {
        var _st = current_time;
        var _result = method_call(_func, _args);
        var _et = current_time - _st;
        log($"{_tag} took ({_et} ms).", "profile");
        return _result;
    }
}
