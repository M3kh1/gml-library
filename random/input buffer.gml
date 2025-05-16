
/// InputBuffer constructor
/// Manages an input queue with a timed buffer window for chaining combos, cancels, or inputs.
/// 
/// Params:
///   _maxSize    = max number of inputs to hold in the buffer
///   _bufferTime = how many frames an input stays active before expiring

function InputBuffer(_maxSize = 8, _bufferTime = 15) constructor
{
    buffer = [];   // Array of buffered inputs (e.g., "light_punch", "jump")
    timers = [];   // Parallel array tracking how many frames each input has existed

    maxSize = _maxSize;
    bufferTime = _bufferTime;
	
    show_debug = false; // Set true to print debug messages to the console

    /// Adds a new input to the buffer and starts its timer
    add = function(_input)
    {
        if (array_length(buffer) >= maxSize)
        {
            popFront(); // Remove oldest input if buffer is full
        }

        array_push(buffer, _input);
        array_push(timers, 0);
		
        if show_debug show_debug_message($"Added input: {_input} | Buffer: {buffer} | Timers: {timers}");
    }

    /// Updates timers for all inputs and removes expired ones
    update = function()
    {
        for (var i = array_length(buffer) - 1; i >= 0; i--)
        {
            timers[i]++;
            if (timers[i] > bufferTime)
            {
                // Remove expired input
                array_delete(buffer, i, 1);
                array_delete(timers, i, 1);
				
                if show_debug show_debug_message("Removed input");
            }
        }
    }

    /// Returns the oldest input in the buffer without removing it
    peek = function()
    {
        return array_length(buffer) > 0 ? buffer[0] : undefined;
    }

    /// Removes and returns the oldest input from the buffer
    consume = function()
    {
        var val = popFront();
		
        if !is_undefined(val)
        {
            if show_debug show_debug_message($"Consumed input: {val}");
        }
		
        return val;
    }

    /// Clears the buffer and resets all timers
    clear = function()
    {
        buffer = [];
        timers = [];
		
        if show_debug show_debug_message($"Buffer cleared | Buffer: {buffer} | Timers: {timers}");
    }

    /// Removes and returns the oldest input from the buffer (used internally)
    popFront = function()
    {
        if (array_length(buffer) == 0) return undefined;
		
        var val = buffer[0];
        array_delete(buffer, 0, 1);
        array_delete(timers, 0, 1);
		
        return val;
    }
}

