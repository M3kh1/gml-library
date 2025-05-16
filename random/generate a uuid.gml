
function generate_ID(_len)
{
	var _combo = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-";
	var _str_len = string_length(_combo);
	var _final_str = "";
	
	repeat(_len)
	{
		_final_str += string_char_at(_combo, irandom(_str_len));
	}
	
	return _final_str;
}
