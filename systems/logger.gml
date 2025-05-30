
enum LogLevel
{
	debug,
	info,
	warning,
	profile,
}

function Logger(_name="Logger", _showLog=true, _showLevels=[LogLevel.debug, LogLevel.info, LogLevel.warning, LogLevel.profile], _showTimeStamp=false) constructor
{
	name = _name;
	logs = [];
	
	showLog = _showLog;
	showLevels = _showLevels;
	showTimeStamp = _showTimeStamp; 
	
	
	logLvlToString = function(_lvl)
	{
		var _finalStr = "";
		switch(_lvl)
		{
			case LogLevel.debug: _finalStr = "debug"; break;
			case LogLevel.info: _finalStr = "info"; break;
			case LogLevel.warning: _finalStr = "warning"; break;
			case LogLevel.profile: _finalStr = "profile"; break;
		}
		
		return _finalStr;
	}
	
	
	function LogData(_msg, _level) constructor
	{
		timeStamp = $"[{current_hour}:{current_minute}:{current_second}]";
		msg = _msg;
		level = _level;
		
	}
	
	log = function(_msg, _lvl)
	{
		
		var _finalMsg = $"[{name}][{logLvlToString(_lvl)}] ~ {_msg}";
		
		// Save the log
		var _logEntry = new LogData(_msg, _lvl);
		array_push(logs, _logEntry); // <-- use LogData here
		
		var _timeStamp = _logEntry.timeStamp;
		
		if showTimeStamp
		{
			_finalMsg = _timeStamp+_finalMsg;
		}

		// Show if enabled
		if (showLog) and (array_contains(showLevels, _lvl))
		{
			show_debug_message(_finalMsg);
		}
		
	}
	
	logInfo = function(_msg)
	{
		log(_msg, LogLevel.info);
	}
	
	logDebug = function(_msg)
	{
		log(_msg, LogLevel.debug);
	}
	
	logWarning = function(_msg)
	{
		log(_msg, LogLevel.warning);
	}
	
	logProfile = function(_msg)
	{
		log(_msg, LogLevel.profile);
	}
	
	doProfile = function(_tag, _func, _args=[])
	{
		
		var _st = current_time;
		
		var _result = method_call(_func, _args);
		
		var _et = current_time - _st;
		
		logProfile($"{_tag} took ({_et} ms).");
		
		return _result;
		
	}
	
	printLog = function(_lvl)
	{
		//idk yet
	}
	
}
