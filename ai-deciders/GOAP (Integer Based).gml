

// When creating goap actions think:
/*
	GOAP gets you to the party.
	The party handles itself.
	
	GOAP is about getting into the right context.

	The agent doesn’t plan every bite of food with GOAP —
	It just planned to get to the fridge.


	Add These:
	
	one thing im thinking is 
	setTimer
	setTargetPosition() or setTargetObject()
	for animations maybe a animation manager?
	
*/

randomize();



#region		<Global Helpers>

function structToArray(_struct)
{
	var _finalArray = [];
		
	var _keys = struct_get_names(_struct);
		
	for(var i=0; i<array_length(_keys); i++)
	{
		array_push(_finalArray, _struct[$ _keys[i]]);
	}
		
	return _finalArray;
		
}


function hashState(_state)
{
	//var keys = struct_get_names(_state);
	//array_sort(keys, true); // VERY IMPORTANT: Sort keys alphabetically
	//var str = "{";
	//for (var i = 0; i < array_length(keys); i++)
	//{
	//    var key = keys[i];
	//    var value = _state[$ key];
	//    str += string(key) + ":" + string(value); // Convert key and value to string consistently
	//    if (i < array_length(keys) - 1)
	//	{
	//        str += ",";
	//    }
	//}
	//str += "}"; // Add delimiters to the start/end for clarity
	//return str;
	
	return string(_state);
}

function copyStruct(_original) 
{
    var copy = {};
    var keys = struct_get_names(_original);
    
    for (var i = 0; i < array_length(keys); i++) 
    {
        var key = keys[i];
        var value = _original[$ key];

        if (is_struct(value))
		{
            // Recursively copy nested struct
            copy[$ key] = copyStruct(value);
        } else {
            // Copy primitive or simple value
            copy[$ key] = value;
        }
    }
    
    return copy;
}


function mergeStructs(_target, _source)
{
    var keys = struct_get_names(_source);
    for (var i = 0; i < array_length(keys); i++)
    {
        var key = keys[i];
        _target[$ key] = _source[$ key];
    }
}


function deepMergeStructs(a, b)
{
    var keys = struct_get_names(b);
    for (var i = 0; i < array_length(keys); i++)
	{
        var key = keys[i];

        if (is_struct(a[$ key]) && is_struct(b[$ key]))
		{
            // Recursively merge nested structs
            deepMergeStructs(a[$ key], b[$ key]);
        } else {
            // Overwrite or assign simple values
            a[$ key] = b[$ key];
        }
    }
}


#endregion



#region	- Enums

enum actionTargetModeExecution
{
	none,
	dontMove, // the movement stuff doesnt happen when interacting 
	interact, // Interact with the target, must already be within valid range
	MoveBeforePerforming,
	PerformWhileMoving,
}

enum registerTargetMode 
{
	NEAREST,
	FURTHEST,
	RANDOM,
	BEST_SCORE,
}

#endregion


function brainGOAP(_ownerObj=other.id) constructor
{
	actions = {};
	goals = {};
	sensors = {};
	targets = {}; 
	
	ownerObj = _ownerObj;
	target = undefined;
	
	show_debug_message($"Owner OBJ: {ownerObj}");
	targetGoal = undefined;
	
	Log = new Logger("GOAP/Brain", true, [LogLevel.debug]);
	
	planner = new plannerGOAP(actions, targetGoal); 
	plan = [];
	currentActionIndex = 0;  // init action index
	
	
	currentActionState = {
	    started: false,
	    startSnapshot: undefined,
	    // other per-action state if needed
	}
	resetActionState = function()
	{
		currentActionState = {
	        started: false,
	        startSnapshot: undefined,
	    };
	}
	

	
	
	#region		- Primary User Functions -
	
	// Action Stuff
	addAction = function(_action)
	{
		
		var _name = _action.name;
		
		if struct_exists(actions, _name)
		{
			Log.logWarning($"Action ({_name}) Exists Already.");
			return;
		}
		
		struct_set(actions, _name, _action);
		
	}
	
	addActionsByArray = function(_actions)
	{
		for(var i=0; i<array_length(_actions); i++)
		{
			var _a = _actions[i];
			addAction(_a);
		}
	}
	
	// Goal Stuff
	addGoal = function(_goal)
	{
		
		var _name = _goal.name;
		
		if struct_exists(goals, _name)
		{
			Log.logWarning($"Goal ({_name}) Exists Already.");
			return;
		}
		
		struct_set(goals, _name, _goal);
		
	}
	
	addGoalsByArray = function(_goals)
	{
		for(var i=0; i<array_length(_goals); i++)
		{
			var _g = _goals[i];
			addGoal(_g);
		}
	}
	
	setTargetGoal = function(_goalName)
	{
		
		//show_debug_message("Goals: "+string(goals));
		if _goalName == undefined
		{
			targetGoal = undefined;
			return;
		}
		
		if !struct_exists(goals, _goalName)
		{
			Log.logWarning("Set target goal failed. Goal DNE.");
			return;
		}
		
		var _tempGoal = struct_get(goals, _goalName);
		if targetGoal != _tempGoal
		{
			targetGoal = _tempGoal;
		} else {
			Log.logWarning("Trying to set a goal thats alrdy chosen.");
		}
		
	}
	
	// Sensor Stuff
	registerSensor = function(_name, _func)
	{
		
		if struct_exists(sensors, _name)
		{
			Log.logWarning($"Sensor ({_name}) Exists Already.");
			return;
		}
		
		struct_set(sensors, _name, _func);
		
	}
	
	getSensorData = function(_name)
	{
		var _sensor = struct_get(sensors, _name);
		
		if _sensor == undefined
		{
			Log.logWarning($"Sensor: {_name} DNE.");
			return false;
		}
		
		return _sensor();
		
	}
	
	
	
	// Target Stuff
	registerTarget = function(_name, _obj, _conditionFunct, _maxRange=undefined, _interactRange=undefined, _mode=registerTargetMode.NEAREST)
	{
		// Optional: targetMode: "nearest" | "random" | "bestScore"
		// bestScore EX: Weighted/scored targets (e.g. "pick bush with most berries")
		if struct_exists(targets, _name)
		{
			Log.logWarning($"Target ({_name}) already registered.");
			return;
		}
	
		var _data = {
			object: _obj,
			conditionFn: _conditionFunct,
			mode: _mode,
			maxRange: _maxRange,
			interactRange: _interactRange,
		};
	
		targets[$ _name] = _data;
	}
	
	isTargetInRange = function(_inst, _maxRange)
	{
		if !instance_exists(_inst) return false; 
		return point_distance(ownerObj.x, ownerObj.y, _inst.x, _inst.y) <= _maxRange;
	}

	
	getTarget = function(_name)
	{
		var _target = targets[$ _name];
		if (_target == undefined)
		{
			Log.logWarning($"Target definition '{_name}' not found.");
			return noone;
		}
	
		if (!instance_exists(_target.object)) return noone;

		// Collect and filter valid instances
		var _validObjects = [];
		for (var i = 0; i < instance_number(_target.object); ++i)
		{
		    var inst = instance_find(_target.object, i);
		    if (instance_exists(inst))
		    {
				var _inRange = true;
				
				if !is_undefined(_target.maxRange)
				{
					_inRange = isTargetInRange(inst, _target.maxRange); 
				}
			
				
				
		        if (_target.conditionFn == undefined || method_call(_target.conditionFn, [inst])) and _inRange
		        {
		            array_push(_validObjects, inst);
		        }
		    }
		}

		if (array_length(_validObjects) == 0)
		{
		    return noone;
		}

		// Choose one based on the target mode
		switch (_target.mode)
		{
			case registerTargetMode.NEAREST:
			
				var nearest = noone;
				var dist = infinity;
				for (var i = 0; i < array_length(_validObjects); ++i)
				{
					var inst = _validObjects[i];
					var d = point_distance(ownerObj.x, ownerObj.y, inst.x, inst.y);
					if (d < dist)
					{
						dist = d;
						nearest = inst;
					}
				}
				return nearest;
			break;
		
		
			case registerTargetMode.FURTHEST:
			
				var furthest = noone;
				var dist = -infinity;
				for (var i = 0; i < array_length(_validObjects); ++i)
				{
					var inst = _validObjects[i];
					var d = point_distance(ownerObj.x, ownerObj.y, inst.x, inst.y);
					if (d > dist)
					{
						dist = d;
						furthest = inst;
					}
				}
				
				return furthest;
			break;
		
		
			case registerTargetMode.RANDOM:
				return _validObjects[irandom(array_length(_validObjects) - 1)];

			case registerTargetMode.BEST_SCORE:
				// Leave this for now until I implement scoring somehow, idfk
				return _validObjects[0];

			default:
				return _validObjects[0];
		}

		return noone; // fallback
	}

	
	#endregion

	#region		[Base Helper Functions]
	
	
	initPlan = function(_plan=[])
	{
		plan = _plan;
		currentActionIndex = 0;
	}
	
	
	generatePlan = function()
	{
	    var _startTime = current_time;
    
	    var current_state = captureSensorSnapshot();
		
		if is_undefined(targetGoal)
		{
			Log.logDebug("No valid plan could be generated.");
			
		    return false;
		}
		
	    var goal_state = targetGoal.conditions;
	    var available_actions = actions;
		
		show_debug_message($"Generating Plan for ({targetGoal.name})");
		show_debug_message($"Total Actions in GOAP Brain: ({array_length(struct_get_names(actions))})");
		
	    var new_plan = planner.createPlan(current_state, goal_state);
		
	    var plan_valid = (array_length(new_plan) > 0);

	    if (!plan_valid)
	    {
			Log.logDebug("No valid plan could be generated.");
			
	        return false;
	    }

	    initPlan(new_plan); // Update plan with the new one

	    var _endTime = (current_time - _startTime);
		
		
		Log.logDebug($"New plan: ({array_length(new_plan)}) generated successfully in ({_endTime} ms | {_endTime/1000} s) so abt. ({round(_endTime/(16.67))} frames).");
		
		printPlan();
		
	    return true;
	}
	
	captureSensorSnapshot = function()
	{
		var _snap = {};
		
		var _sensor_names = struct_get_names(sensors);
		
		for(var i=0; i<array_length(_sensor_names); i++)
		{
			var _name = _sensor_names[i];
			
			var _val = struct_get(sensors, _name);
			
			var _funct_ran = _val();
			
			struct_set(_snap, _name, _funct_ran);
		}
		
		return _snap;
		
	}

	printPlan = function()
	{
		var _len = array_length(plan);
		
		if (_len <= 0)
		{
			show_debug_message("Print Plan - Plan is empty.");
			return;
		}
		
		show_debug_message($"({_len}) ~ Printing Plan:");
		
		//show_debug_message(string(plan));
		
		for(var a=0; a<_len; a++)
		{
			
			var _act = plan[a];
			show_debug_message($"{a+1}: {_act}");
			
		}
		
	}
	

	drawSensors = function(_x, _y)
	{
		var _sensor_names = struct_get_names(sensors);
		
		for(var i=0; i<array_length(_sensor_names); i++)
		{
			var _sensor = _sensor_names[i];
			var _val = struct_get(sensors, _sensor);
			
			draw_text(_x, (_y-(20*i)), $"Sensor: {_sensor} ~ {_val()}");
			
		}
		
	}
	
	#endregion
	
	#region		<Run the Plan>
	
	LogPlanExe = new Logger("GOAP/Brain/Plan-Executor", true, [LogLevel.warning]);
	
	checkReactionDelta = function(startState, endState, expectedChanges)
	{
	    var keys = struct_get_names(expectedChanges);

	    for (var i = 0; i < array_length(keys); i++)
	    {
	        var key = keys[i];

	        if (!struct_exists(startState, key) || !struct_exists(endState, key))
	        {
	            show_debug_message("Missing key: " + key);
	            return false;
	        }

	        var expected = expectedChanges[$ key];
	        var startVal = startState[$ key];
	        var endVal = endState[$ key];

	        // If expected is bool, just compare directly
	        if (is_bool(expected))
	        {
	            if (endVal != expected) return false;
	        }
	        else
	        {
	            var delta = endVal - startVal;
	            if (delta != expected && endVal != expected) return false;
	        }
	    }

	    return true;
	}
	
	goalComplete = function()
	{
		LogPlanExe.logInfo($"Plan Completed For Goal: {targetGoal.name}");
	    generatePlan();
	}

	handleFailure = function()
	{
	    //show_debug_message("[GOAP] Plan failed.");
	    generatePlan();
		
	}

	handleInterruption = function()
	{
	    //show_debug_message("[GOAP] Plan interrupted. Replanning...");
	    generatePlan();
	}
	
	
    resolveTargetForAction = function(_action)
	{
		if (_action.targetKey == undefined) return noone;

		var def = targets[$ _action.targetKey];
		if (def == undefined) return noone;

		var inst = getTarget(_action.targetKey);
		if (inst == noone) return noone;
		if (def.conditionFn != undefined && !method_call(def.conditionFn, [inst])) return noone;

		return inst;
	}

	
	hasReachedTarget = function(target)
	{
	    var target_x, target_y;
		var tolerance = 1;
		
	    // Handle both object and position input
	    if (instance_exists(target))
	    {
			//target = instance_nearest(ownerObj.x, ownerObj.y, target);
			
	        target_x = target.x;
	        target_y = target.y;
	    }
	    else if (is_array(target) && array_length(target) == 2)
	    {
	        target_x = target[0];
	        target_y = target[1];
	    }
	    else
	    {
	        show_debug_message("Invalid target type passed to hasReachedTarget()");
	        return true;
	    }

	    var dist = point_distance(ownerObj.x, ownerObj.y, target_x, target_y);
	    return (dist <= tolerance); // Adjust tolerance as needed
	}

	moveTowardTarget = function(target, spd = 1)
	{
	    var target_x, target_y;

	    if (instance_exists(target))
	    {
			//target = instance_nearest(ownerObj.x, ownerObj.y, target);
	        target_x = target.x;
	        target_y = target.y;
	    }
	    else if (is_array(target) && array_length(target) == 2)
	    {
	        target_x = target[0];
	        target_y = target[1];
	    }
	    else
	    {
	        show_debug_message("Invalid target type passed to moveTowardTarget()");
	        return;
	    }

	    var angle = point_direction(ownerObj.x, ownerObj.y, target_x, target_y);
	    ownerObj.x += lengthdir_x(spd, angle);
	    ownerObj.y += lengthdir_y(spd, angle);
	}

	selectGoal = function()
	{
		
		var _goals = structToArray(goals);
		var _highestUrgency = -infinity;
		var _bestGoal = undefined;
		
		for(var i=0; i<array_length(_goals); i++)
		{
			var _goal = _goals[i];
			var _currState = captureSensorSnapshot();
			var _targetState = _goal.conditions;
			var _goalPriority = _goal.priority;
			
			var _urgency = (planner.simpleHeuristic(_currState, _targetState) * _goalPriority);
			
			if _urgency > _highestUrgency
			{
				_highestUrgency = _urgency; // Update the highest urgency found so far
				_bestGoal = _goal; // Store this goal as the current "best" candidate
			}
			
		}
		
		var minimumActivationUrgency = 1; // Or 0, depending on your urgency scale.
	    if (_highestUrgency > minimumActivationUrgency) and (_bestGoal != undefined) 
		{
	        //show_debug_message($"Found best goal: {_bestGoal.name} with urgency: {_highestUrgency}");
	        setTargetGoal(_bestGoal.name);
	    } else {
	        //show_debug_message("No goal found with sufficient urgency. AI may go idle.");
			setTargetGoal(undefined);

	    }
		
	}
	
	
	// Run everything
	doPlan = function()
	{
	    selectGoal(); // cache the best goals based on the current state of the GOAP agent to help

	    if (targetGoal == undefined) return;

	    if (planner.checkKeysMatch(targetGoal.conditions, captureSensorSnapshot()))
	    {
	        LogPlanExe.logDebug($"Target Goal: {targetGoal.name} already completed.");
	        return;
	    }

	    if (plan == undefined || array_length(plan) == 0)
	    {
	        LogPlanExe.logWarning("Plan isn't valid.");
	        generatePlan();
	        return;
	    }

	    if (currentActionIndex >= array_length(plan))
	    {
	        goalComplete();
	        return;
	    }

	    var actionName = plan[currentActionIndex];
	    if (!struct_exists(actions, actionName))
	    {
	        LogPlanExe.logWarning($"Action '{actionName}' does not exist.");
	        handleFailure();
	        return;
	    }

	    var action = actions[$ actionName];


		
	    // Handle action execution state:
	    if (!currentActionState.started)
	    {
			
	        // Check preconditions once before starting
	        if (!planner.checkKeysMatch(action.conditions, captureSensorSnapshot()))
	        {
	            LogPlanExe.logDebug($"Preconditions failed for '{actionName}' (before start). Replanning...");
	            generatePlan();
	            return;
	        }
			
			
			
			action.target = resolveTargetForAction(action);
			if (action.target == noone && action.targetMode != actionTargetModeExecution.none)
			{
				LogPlanExe.logWarning("Failed to resolve target.");
				resetActionState();
				generatePlan();
				return;
			}
			
			var _t = action.target;
			
			switch (action.targetMode)
			{
				case actionTargetModeExecution.MoveBeforePerforming:
					if (!hasReachedTarget(_t))
					{
						moveTowardTarget(_t);
						return; // Wait until we're in range
					}
					
				break;


				case actionTargetModeExecution.PerformWhileMoving:
					moveTowardTarget(_t); // Start moving and let it act while in motion
				break;
				
				case actionTargetModeExecution.interact:
					
					var _range = action.maxInteractionRange;
					
					if is_undefined(_range)
					{
						break; // means that it can interact from anywhere
					}
					
					if (!point_distance(ownerObj.x, ownerObj.y, _t.x, _t.y) <= _range)
				    {
						show_debug_message($"Cannot Interact from: {_range}");
						return;
				    }
					
				break;


				case actionTargetModeExecution.dontMove:
					// Don't move, just wait - target must still be valid and nearby
					
					var def = targets[$ action.targetKey];
					if (def != undefined && def.conditionFn != undefined && !method_call(def.conditionFn, [action.target]))
					{
						LogPlanExe.logWarning("Target became invalid before execution. Replanning...");
						resetActionState();
						generatePlan();
						return;
					}
					
					
				break;


				case actionTargetModeExecution.none:
					// No target or movement involved
					return;
				break;
			}

			

	        // Mark action started
	        currentActionState.started = true;
	        currentActionState.startSnapshot = captureSensorSnapshot();
			
	        // Call action's execute function
	        action.execute();

	        return; // wait for next frame to check progress
	    }
	    else
	    {
	        // Action is running - check for success by comparing reactions
	        if (checkReactionDelta(currentActionState.startSnapshot, captureSensorSnapshot(), action.reactions))
	        {
	            LogPlanExe.logInfo($"{actionName} completed.");
                
	            // Reset action state and move to next action
				resetActionState();
				
	            currentActionIndex++;
	            return;
	        }
			
			// Recheck if target still meets the condition
			if (action.target != noone && action.targetMode != actionTargetModeExecution.none)
			{
				var def = targets[$ action.targetKey];
				if (def != undefined && def.conditionFn != undefined && !method_call(def.conditionFn, [action.target]))
				{
					LogPlanExe.logWarning("Target became invalid during execution. Replanning...");
					resetActionState();
					generatePlan();
					return;
				}
			}


	        // Check for interruption
	        if (action.isInterruptible && !planner.checkKeysMatch(action.conditions, captureSensorSnapshot()))
	        {
	            LogPlanExe.logInfo($"{actionName} was interrupted.");
                
	            // Reset and replan
	            resetActionState();
	            handleInterruption();
	            return;
	        }

	        // Still running, wait for next frame
	        return;
	    }
	}
	


	#endregion
	
	

}


function plannerGOAP(_allActions, _targetGoal) constructor
{
	planLog = new Logger("GOAP/Planner", true, [LogLevel.info, LogLevel.warning, LogLevel.profile]);
	
    plan_cache = {};			// Cache for previously generated plans
	heuristic_cache = {};
	simulation_cache = {};
	
	allActions = _allActions;
	
	conditionGraph = undefined;	// init ONCE
	reactionGraph = undefined; // init ONCE
	actionCostData = undefined; // init ONCE
	
	targetGoal = _targetGoal;
	
	
	getAverageActionCost = function()
	{
	    var _actions = structToArray(allActions);
	    var _count = array_length(_actions);

	    if (_count == 0) return 0; // Avoid divide by zero

	    var _totalCost = 0;
	    for (var i = 0; i < _count; i++)
	    {
	        var _act = _actions[i];
	        _totalCost += _act.cost;
	    }

	    var _avg = _totalCost / _count;
	    //show_debug_message("Average action cost: " + string(_avg));

	    return _avg;
	}
	
	averageActionCost = getAverageActionCost();
	
	
	#region	--- All Helper Functions ---


	setupActionData = function()
	{
		if (is_undefined(conditionGraph) and is_undefined(reactionGraph))
		{
			//var _graphs = planLog.doProfile("buildDependencyMaps",buildDependencyMaps);
			var _graphs = buildDependencyMaps();
			conditionGraph = _graphs.con;
			reactionGraph = _graphs.react;
			
			//show_debug_message($"Condition Graph:\n {conditionGraph}");
			//show_debug_message($"Reaction Graph:\n {reactionGraph}");
			
			actionCostData = calculateMinActionCostsHeuristicData();
		}
		
	}
	
	
	#region		--- Heuristic Functions ---
	
	
	function simpleHeuristic(_state, _goal)
	{
        var error = 0;
        var keys = struct_get_names(_goal);
        for (var i = 0; i < array_length(keys); i++)
		{
            var key = keys[i];
            if (!keyMatches(_state, _goal, key)) error++;

        }
        return error;
    }
	
	function goalHeuristic(_currentState, _goalState, _unmet)
	{
		var _startMS = current_time;
		
	    var _totalHeuristicCost = 0;
	    var _unmetConditions = _unmet;
		
		
		var _minCostPerKey = actionCostData.MinCostPerKey;
		var _minCostToAchieve = actionCostData.MinCostToAchieve;

	    var _avg_cost = averageActionCost; // Still a useful fallback

	    for (var i = 0; i < array_length(_unmetConditions); i++)
	    {
	        var _key = _unmetConditions[i];

        
	        var _goalDefinition = _goalState[$ _key]; 

	        // --- NEW/UPDATED LOGIC: Handle missing keys using calculated heuristic data ---
	        if (!struct_exists(_currentState, _key))
	        {
	            var cost_for_missing_key = _avg_cost; // Default fallback if no specific data is found

	            if (is_struct(_goalDefinition)) // It's a numerical comparison goal (e.g., {comparison:">=", value:10})
	            {
	                // Estimate the cost to get to the required amount from zero, using cost_per_unit
	                var needed_amount = _goalDefinition.value;
                
	                // Use global.GOAP_MinCostPerUnit_Data if available, otherwise fallback to average
	                var cost_per_unit = struct_exists(_minCostPerKey, _key) ? _minCostPerKey[$ _key] : _avg_cost;
                
	                cost_for_missing_key = needed_amount * cost_per_unit;
	                if (cost_for_missing_key <= 0) cost_for_missing_key = _avg_cost; // Ensure minimum if goal value is 0 or less
	            }
	            else // It's a simple boolean/value goal (e.g., true, "item_name", or 0/1)
	            {
	                var target_value_str = string(_goalDefinition);
                
	                // Use global.GOAP_MinCostToAchieve_Data for direct lookup
	                if (struct_exists(_minCostToAchieve, _key) && struct_exists(_minCostToAchieve[$ _key], target_value_str))
	                {
	                    cost_for_missing_key = _minCostToAchieve[$ _key][target_value_str];
	                }
	            }
            
	            _totalHeuristicCost += cost_for_missing_key;
	            continue; // Move to the next unmet condition
	        }

	        // --- Existing logic for keys that exist but don't meet the goal ---
	        var _currentValue = _currentState[$ _key];

	        // Now, use the getConditionGap function, which will also be updated to use the new data
	        // We'll pass the global heuristic data to getConditionGap
	        var _val = getConditionGap(_currentValue, _goalDefinition, _key);
	        _totalHeuristicCost += _val;
	    }


		//show_debug_message($"Goal Heuristic MS: {current_time - _startMS}");

	    return _totalHeuristicCost;
	}
	
	
	function calculateHeuristic (_currentState, _goalState, _stateHash, _goalStateHash, _unmet)
	{
		var _key = _stateHash + "|" + _goalStateHash;
		
		//show_debug_message($"heuristic_cache size: {array_length(struct_get_names(heuristic_cache))}");

		
		if (struct_exists(heuristic_cache, _key))
		{
			var _data = struct_get(heuristic_cache, _key);
			
			//show_debug_message("Heuristic cache hit.");
			
			return _data;
		}
		
		//show_debug_message($"Heuristic cache NOT hit");
		
		var _h = goalHeuristic(_currentState, _goalState, _unmet);
	    struct_set(heuristic_cache, _key, _h);
		
	    return _h;
	}
	
	
	/// @description Calculates and stores the minimum cost per unit for numerical keys and minimum cost to achieve specific states for direct keys, using the reactionGraph.
	function calculateMinActionCostsHeuristicData()
	{
	    var MinCostPerKey = {};      // Stores { "key_name": min_cost_per_key_value, ... }
	    var MinCostToAchieve = {};   // Stores { "key_name": { "target_value_string": min_cost, ... }, ... }


	    var _reactionKeys = struct_get_names(reactionGraph);

	    for (var i = 0; i < array_length(_reactionKeys); i++)
	    {
	        var _reactionKey = _reactionKeys[i]; // e.g., "Ammo", "HasWeapon", "Scrap"
	        var _affectingActionNames = reactionGraph[$ _reactionKey]; // Array of action names that react to this key

	        for (var j = 0; j < array_length(_affectingActionNames); j++)
	        {
	            var action_name = _affectingActionNames[j];
	            var _action = allActions[$ action_name]; // Get the full action definition
	            var _action_cost = _action.cost;

	            // Now, examine the specific reaction for this action and key
	            var _reactionEffect = _action.reactions[$ _reactionKey];
				
				if is_undefined(_reactionEffect) continue;
				
				
				// --- Logic for Populating Heuristic Tables ---
            
	            // 1. Populate MinCostPerKey (for numerical quantities that are NOT booleans 0/1)
	            // This is for resources like "Ammo", "Scrap", "Wood" where you want a cost per incremental unit.
	            // Exclude 0 and 1 as they typically represent boolean true/false states in your system.
	            if (is_numeric(_reactionEffect) && _reactionEffect != 0 && _reactionEffect != 1)
	            {
	                var cost_per_unit = _action_cost / abs(_reactionEffect); // Cost per unit of magnitude change
                
	                // Update MinCostPerKey for this key if this action is cheaper per unit
	                if (!struct_exists(MinCostPerKey, _reactionKey) || cost_per_unit < MinCostPerKey[$ _reactionKey])
	                {
	                    MinCostPerKey[$ _reactionKey] = cost_per_unit;
	                }
	            }
            
	            // 2. Populate MinCostToAchieve (for all specific target states: booleans, strings, and exact numbers)
	            // This is for states like "HasWeapon: true", "Location: Town", "Ammo: 0", "Health: 100".
	            // All values (numbers, booleans, strings) are converted to strings for consistent lookup keys.
	            var target_value_str = string(_reactionEffect); // Convert to string for keying

	            if (!struct_exists(MinCostToAchieve, _reactionKey))
	            {
	                MinCostToAchieve[$ _reactionKey] = {};
	            }
	            // If this is the first time we've seen this target value for this key, or if this action is cheaper
	            if (!struct_exists(MinCostToAchieve[$ _reactionKey], target_value_str) || _action_cost < MinCostToAchieve[$ _reactionKey][$ target_value_str])
	            {
	                MinCostToAchieve[$ _reactionKey][$ target_value_str] = _action_cost;
	            }


	        }
	    }
		
		

	    // Optional: Log the results for debugging
	    //show_debug_message("Calculated Min Heuristic Costs:");
	    //show_debug_message(" ~ MinCostPerKey: " + string(MinCostPerKey));
	    //show_debug_message(" ~ MinCostToAchieve: " + string(MinCostToAchieve));
		
		return {
			MinCostPerKey: MinCostPerKey,
			MinCostToAchieve: MinCostToAchieve,
		}
	}

	function getConditionGap(_state_value, _target_condition_struct, _key_name = "unknown_key")
	{
	    var _avg_cost = averageActionCost;
	    var _minCostPerKey = actionCostData.MinCostPerKey;
	    var _minCostToAchieve = actionCostData.MinCostToAchieve;

	    if (!is_struct(_target_condition_struct) || !struct_exists(_target_condition_struct, "comparison"))
	    {
	        planLog.logWarning($"getConditionGap: Target condition for '{_key_name}' is not a valid struct.");
	        return 999999999;
	    }

	    var operator = _target_condition_struct.comparison;
	    var target_value = _target_condition_struct.value;

	    // Determine unit cost for numeric comparisons
	    var cost_per_unit = _avg_cost;
	    if (struct_exists(_minCostPerKey, _key_name))
	    {
	        cost_per_unit = max(_minCostPerKey[$ _key_name], 0.01); // Prevent zero cost
	    }

	    switch (operator)
	    {
	        case ">=":
	            return max(0, target_value - _state_value) * cost_per_unit;

	        case "<=":
	            return max(0, _state_value - target_value) * cost_per_unit;

	        case ">":
	            return max(0, (target_value - _state_value) + 1) * cost_per_unit;

	        case "<":
	            return max(0, (_state_value - target_value) + 1) * cost_per_unit;

	        case "==":
	            if (_state_value == target_value)
	            {
	                return 0;
	            }

	            // For direct values (like bools), use precomputed cost
	            var min_cost_for_value = _avg_cost;
	            var target_value_str = string(target_value);

	            if (struct_exists(_minCostToAchieve, _key_name))
	            {
	                if (struct_exists(_minCostToAchieve[$ _key_name], target_value_str))
	                {
	                    min_cost_for_value = _minCostToAchieve[$ _key_name][$target_value_str];
	                }
	            }

	            return min_cost_for_value;

	        default:
	            planLog.logWarning($"getConditionGap: Unknown comparison operator '{operator}' for key '{_key_name}'.");
	            return 999999999;
	    }
	}

	
	#endregion
	
	
	#region		--- Other Helper ---
	
	// Helper: checks if all conditions keys exist in knownFacts (ignoring values)
	function areAllConditionsMet(conditions, knownFacts)
	{
	    var keys = struct_get_names(conditions);
	    for (var i = 0; i < array_length(keys); i++)
		{
	        var k = keys[i];
	        if (!struct_exists(knownFacts, k)) return false;
	    }
	    return true;
	}


	function checkKeysMatch(_conditions_or_reactions, _state_to_check) // Renamed parameters for clarity
	{
	    var _keys = struct_get_names(_conditions_or_reactions); // Iterate keys from the conditions/reactions set
	    for (var i = 0; i < array_length(_keys); i++)
	    {
	        var _key = _keys[i];
	        // Call keyMatches with STATE first, then CONDITIONS/REACTIONS
	        if (!keyMatches(_state_to_check, _conditions_or_reactions, _key)) 
	        { 
	            return false; // If ANY key doesn't match, the whole set doesn't match
	        }
	    }
	    return true; // If all keys matched, the whole set matches
	}

	
	function keyMatches(_state_to_check, _target_struct, _key_to_check)
	{
	    // Check if the key exists in the state we are checking against
	    if (!struct_exists(_state_to_check, _key_to_check))
	    {
	        // If the key isn't in the state, the condition isn't met.
	        // planLog.logDebug($"keyMatches: Key '{_key_to_check}' not found in state."); // Optional debug
	        return false;
	    }

	    var state_value = _state_to_check[$ _key_to_check];
	    var condition_definition = _target_struct[$ _key_to_check]; // Get the condition definition from the target struct (either goal or action conditions)


	    var operator = condition_definition.comparison;
	    var target_value = condition_definition.value;

	    // Ensure both state value and target value are numeric for numerical comparison
	    if (!is_numeric(state_value) || !is_numeric(target_value))
	    {
	        // If either isn't numeric, the condition can't be numerically matched.
	        planLog.logWarning($"keyMatches: Numerical comparison for key '{_key_to_check}' requires numeric values. State is '{string(state_value)}', Target is '{string(target_value)}'.");
	        return false;
	    }

	    var result = false; // Initialize the boolean result for the comparison

	    // Perform the numerical comparison based on the operator string
	    switch (operator)
	    {
	        case ">=": result = state_value >= target_value; break;
	        case "<=": result = state_value <= target_value; break;
	        case ">":  result = state_value > target_value; break;
	        case "<":  result = state_value < target_value; break;
	        case "==":  result = state_value == target_value; break;

	        default:
	            planLog.logWarning($"keyMatches: Unknown comparison operator '{operator}' for key '{_key_to_check}'.");
	            return false; // An unknown operator means the condition is not met
	    }
			
		if (!result)
		{
			//show_debug_message("keyMatches: Numeric condition failed for key '" + string(_key_to_check) + "'. State: " + string(state_value) + " " + string(operator) + " " + string(target_value));
		}
			
	    return result; // Return the actual boolean result of the numerical comparison
	    
	}
	
	
	function keyMatchesValue(actual, expected)
	{
	    
	    if (!struct_exists(expected, "comparison") || !struct_exists(expected, "value")) return false;

	    var comp = expected.comparison;
	    var val = expected.value;

	    switch (comp)
		{
	        case "==": return actual == val;
	        case "<":  return actual < val;
	        case "<=": return actual <= val;
	        case ">":  return actual > val;
	        case ">=": return actual >= val;
	        default: return false;
	    }
	    

	    // Otherwise, just compare directly
	    return actual == expected;
	}

	
	getPlanActionNames = function(_plan)
	{
		var _temp = [];
		for(var i=0; i<array_length(_plan); i++)
		{
			var _act = _plan[i];
			var _name = _act.name;
			
			array_push(_temp, _name);
		}
		
		return _temp;
	}
	
	
	getPlanCost = function(_plan)
	{
		var _total = 0;
		for(var i=0; i<array_length(_plan); i++)
		{
			var _act = _plan[i];
			var _cost = _act.cost;
			//var _name = _act.name;
			
			_total += _cost;
		}
		
		return _total;
	}
	

	array_slice = function(_array, _start, _length)
	{
	    var _result = [];
	    var _end = _start + _length;
	    var _count = array_length(_array);
    
	    // Clamp the end to array bounds
	    if (_start < 0) _start = 0;
	    if (_end > _count) _end = _count;

	    for (var i = _start; i < _end; i++)
		{
	        array_push(_result, _array[i]);
	    }

	    return _result;
	}

	
	function anyKeysMatch(_keysA, _keysB)
	{ 
		
		_keysA = struct_get_names(_keysA);
		_keysB = struct_get_names(_keysB);
		
	    for (var i = 0; i < array_length(_keysA); i++)
		{
	        var _keyA = _keysA[i];
	        for (var j = 0; j < array_length(_keysB); j++)
			{
	            var _keyB = _keysB[j];
	            if (_keyA == _keyB)
				{
	                return true; // Found a match, no need to check further
	            }
	        }
	    }
	    return false; // No common keys found after checking all combinations
	}


	
	// Find Actions That Depend On the Current Action
	getDependentActions = function(currentActionName)
	{
	    var action = allActions[$ currentActionName];
	    if (action == undefined) return [];

	    var dependentActions = [];
	    var reactKeys = struct_get_names(action.reactions);

	    for (var i = 0; i < array_length(reactKeys); i++)
	    {
	        var key = reactKeys[i];
	        var consumers = reactionGraph[$ key]; // <- actions that consume this key
	        if (consumers != undefined)
	        {
	            for (var j = 0; j < array_length(consumers); j++)
	            {
	                var actName = consumers[j];
	                if (!array_contains(dependentActions, actName))
					{
	                    array_push(dependentActions, actName);
					}
	            }
	        }
	    }

	    return dependentActions;
	}

	//  Find Actions That Enable the Current Action
	getEnablingActions = function(currentActionName)
	{
	    var action = allActions[$ currentActionName];
	    if (action == undefined) return [];

	    var enablingActions = [];
	    var condKeys = struct_get_names(action.conditions);

	    for (var i = 0; i < array_length(condKeys); i++)
	    {
	        var key = condKeys[i];
	        var producingActs = conditionGraph[$ key]; // <- actions that produce this key
	        if (producingActs != undefined)
	        {
	            for (var j = 0; j < array_length(producingActs); j++)
	            {
	                var actName = producingActs[j];
	                if (!array_contains(enablingActions, actName))
	                    array_push(enablingActions, actName);
	            }
	        }
	    }

	    return enablingActions;
	}

	
	function getBackwardReachableConditions(_goalState)
	{
	    var reachable = {};
	    var queue = [];

	    var goalKeys = struct_get_names(_goalState);
	    for (var i = 0; i < array_length(goalKeys); i++)
        {
	        var key = goalKeys[i];
	        reachable[$ key] = true;
	        array_push(queue, key);
	    }

	    while (array_length(queue) > 0)
        {
	        var key = array_shift(queue);
	        var producers = conditionGraph[$ key];
	        if (producers == undefined) continue;

	        for (var i = 0; i < array_length(producers); i++)
            {
	            var actionName = producers[i];
	            var action = allActions[$ actionName];
	            if (action == undefined || action.conditions == undefined) continue;

	            var condKeys = struct_get_names(action.conditions);
	            for (var j = 0; j < array_length(condKeys); j++) {
	                var condKey = condKeys[j];
	                if (!struct_exists(reachable, condKey)) {
	                    reachable[$ condKey] = true;
	                    array_push(queue, condKey);
	                }
	            }
	        }
	    }

	    return reachable;
	}

	
	function getForwardReachableConditions(_state)
	{
	    var reachable = {};
	    var queue = [];

	    var stateKeys = struct_get_names(_state);
	    for (var i = 0; i < array_length(stateKeys); i++) {
	        var key = stateKeys[i];
	        reachable[$ key] = true;
	        array_push(queue, key);
	    }

	    while (array_length(queue) > 0) {
	        var key = array_shift(queue);
	        var reactions = reactionGraph[$ key];
	        if (reactions == undefined) continue;

	        for (var i = 0; i < array_length(reactions); i++) {
	            var actName = reactions[i];
	            var action = allActions[$ actName];
	            if (action == undefined || action.reactions == undefined) continue;

	            var effectKeys = struct_get_names(action.reactions);
	            for (var j = 0; j < array_length(effectKeys); j++) {
	                var effKey = effectKeys[j];
	                if (!struct_exists(reachable, effKey)) {
	                    reachable[$ effKey] = true;
	                    array_push(queue, effKey);
	                }
	            }
	        }
	    }

	    return reachable;
	}

	
	
	#endregion
	
	
	#region		--- Graphs ---
	
	
	buildActionDependencyGraph = function()
	{
	    var _allActs = structToArray(allActions);
	    var _forwardGraph = {};
	    var _backwardGraph = {};

	    for (var i = 0; i < array_length(_allActs); i++)
	    {
	        var _actA = _allActs[i];
	        var _forwardList = [];

	        for (var j = 0; j < array_length(_allActs); j++)
	        {
	            var _actB = _allActs[j];

	            if (anyKeysMatch(_actB.conditions, _actA.reactions))
	            {
	                // Forward: A -> B
	                array_push(_forwardList, _actB.name);

	                // Backward: B <- A
	                if (!struct_exists(_backwardGraph, _actB.name))
	                {
	                    _backwardGraph[$ _actB.name] = [];
	                }
	                array_push(_backwardGraph[$ _actB.name], _actA.name);
	            }
	        }

	        _forwardGraph[$ _actA.name] = _forwardList;

	        // Ensure all nodes exist in both graphs, even if empty
	        if (!struct_exists(_backwardGraph, _actA.name))
	        {
	            _backwardGraph[$ _actA.name] = [];
	        }
	    }

	    return {
	        forward: _forwardGraph,
	        backward: _backwardGraph
	    };
	}


	buildDependencyMaps = function()
	{
		var _allActions = structToArray(allActions);
	    var preMap = {};
	    var effMap = {};

	    for (var k = 0; k < array_length(_allActions); k++)
		{
	        var act = _allActions[k];

	        var condKeys = struct_get_names(act.conditions);
	        for (var i = 0; i < array_length(condKeys); i++)
			{
	            var key = condKeys[i];
	            if (!struct_exists(preMap, key)) preMap[$ key] = [];
	            array_push(preMap[$ key], act.name);
	        }

	        var effectKeys = struct_get_names(act.reactions);
	        for (var i = 0; i < array_length(effectKeys); i++)
			{
	            var key = effectKeys[i];
	            if (!struct_exists(effMap, key)) effMap[$ key] = [];
	            array_push(effMap[$ key], act.name);
	        }
	    }

	    return {con: preMap, react: effMap};
	}
	
	
	#endregion
	
	
	#region		--- GET KEYS ---
	
	// non-explicit + explicit keys
	function getAllUnmetConditions(_goalState, _currentState)
	{
		
	    // First get explicit unmet conditions
	    var explicitUnmet = getUnmetConditions(_goalState, _currentState);
    
	    // Then get non-explicit ones building from those
	    var nonExplicitUnmet = getUnmetNonExplicitConditions(_goalState, _currentState);
		
		var _allKeys = array_concat(explicitUnmet, nonExplicitUnmet);
		
	    // Combine results
	    return _allKeys;
	}
	

	// explicit keys 
	function getUnmetConditions(_conditions, _state)
	{
		var unmet = [];
		var _keys = struct_get_names(_conditions);

		for (var i = 0; i < array_length(_keys); i++)
		{
			var _key = _keys[i];

			if (!keyMatches(_state, _conditions, _key))
			{
				array_push(unmet, _key);
			}
		}
	
		return unmet;
	}


	// non-explicit keys
	function getUnmetNonExplicitConditions(_goal, _state) 
	{
	    var explicitKeys = struct_get_names(_goal);
	    var explicitKeyLookup = {};  // O(1) lookup for explicit keys
	    var visited = {};
	    var queue = [];
	    var result = [];  // Build result directly instead of using intermediate struct
    
	    // Create lookup table for explicit keys (avoids array_contains later)
	    for (var i = 0; i < array_length(explicitKeys); i++) 
	    {
	        explicitKeyLookup[$ explicitKeys[i]] = true;
	    }
    
	    // Seed queue with unmet explicit conditions
	    for (var i = 0; i < array_length(explicitKeys); i++) 
	    {
	        var key = explicitKeys[i];
	        if (!keyMatches(_state, _goal, key)) 
	        {
	            visited[$ key] = true;
	            array_push(queue, key);
	        }
	    }
    
	    // BFS through condition graph
	    var queueIndex = 0;  // Use index instead of array_shift for better performance
	    while (queueIndex < array_length(queue)) 
	    {
	        var currentKey = queue[queueIndex++];
        
	        // Check if producers exist for this key
	        if (!struct_exists(conditionGraph, currentKey)) continue;
        
	        var producers = conditionGraph[$ currentKey];
	        for (var j = 0; j < array_length(producers); j++) 
	        {
	            var actionKey = producers[j];
            
	            // Check if action exists
	            if (!struct_exists(allActions, actionKey)) continue;
            
	            var action = allActions[$ actionKey];
            
	            // Skip if no conditions
	            if (!struct_exists(action, "conditions")) continue;
            
	            var preKeys = struct_get_names(action.conditions);
	            for (var k = 0; k < array_length(preKeys); k++) 
	            {
	                var preKey = preKeys[k];
                
	                // Skip if already visited
	                if (struct_exists(visited, preKey)) continue;
                
	                // Only process if condition is unmet
	                if (!keyMatches(_state, action.conditions, preKey)) 
	                {
	                    visited[$ preKey] = true;
	                    array_push(queue, preKey);
                    
	                    // Add directly to result if not explicit (avoid second pass)
	                    if (!struct_exists(explicitKeyLookup, preKey)) 
	                    {
	                        array_push(result, preKey);
	                    }
	                }
	            }
	        }
	    }
    
	    return result;
	}
	

	#endregion
	
	
	#region		--- Filter Actions ---

	
	
	function collectRelevantActions(_conditionsToMeet)
	{
	    // Use a struct to track all unique actions encountered during the traversal.
	    // The keys of this struct will be the unique action names.
	    var _collectedActions = {};

	    // Use an array to simulate a queue for conditions that we need to find actions for.
	    var _conditionsQueue = [];

	    // Initialize the queue with the starting conditions that need to be met.
	    for (var i = 0; i < array_length(_conditionsToMeet); i++)
	    {
	        array_push(_conditionsQueue, _conditionsToMeet[i]);
	    }

	    var head = 0; // This acts as a pointer to the front of our queue

	    // Loop as long as there are conditions in the queue to process
	    while (head < array_length(_conditionsQueue))
	    {
	        var _keyToMeet = _conditionsQueue[head++]; // Dequeue the next condition key

	        // Find actions that *produce* this _keyToMeet (i.e., whose reactions contain this key)
	        if (struct_exists(reactionGraph, _keyToMeet))
	        {
	            var _producingActions = reactionGraph[$ _keyToMeet];

	            // Iterate through each action that can produce this key
	            for (var j = 0; j < array_length(_producingActions); j++)
	            {
	                var _actName = _producingActions[j];

	                // If this action has not already been added to our collected list
	                if (!struct_exists(_collectedActions, _actName))
	                {
	                    struct_set(_collectedActions, _actName, true); // Mark this action as collected (add to struct)

	                    var _act = allActions[$ _actName]; // Get the full action object

	                    // If the action exists and has preconditions
	                    if (_act != undefined && struct_exists(_act, "conditions"))
	                    {
	                        var _actConditionsKeys = struct_get_names(_act.conditions);

	                        // Enqueue all preconditions of this action for further processing
	                        // This ensures we find actions needed for *this action's* conditions
	                        for (var k = 0; k < array_length(_actConditionsKeys); k++)
	                        {
	                            array_push(_conditionsQueue, _actConditionsKeys[k]);
	                        }
	                    }
	                }
	            }
	        }
	    }

	    // After processing all conditions and their related actions,
	    // convert the keys of the _collectedActions struct into a final array to return.
	    return struct_get_names(_collectedActions);
	}


	function filterActionsByNegativeEffects(_actions, _currentState, _unmetGoalKeys, _goalState)
	{
	    var _filteredActions = [];

	    for (var i = 0; i < array_length(_actions); i++)
	    {
	        var _actName = _actions[i];
	        var _act = allActions[$ _actName];
	        if (_act == undefined || _act.reactions == undefined) continue;

	        var _actReactions = _act.reactions;
	        var _hasUndesirableEffect = false;

	        // Loop through only keys this action affects that are also unmet
	        for (var j = 0; j < array_length(_unmetGoalKeys); j++)
	        {
	            var _unmetKey = _unmetGoalKeys[j];

	            // Quick skip if this action does not affect the key
	            if (!struct_exists(_actReactions, _unmetKey)) continue;

	            var _reactionValue = _actReactions[$ _unmetKey];

	            // Avoid full struct lookup if key doesn't exist in goal
	            if (!struct_exists(_goalState, _unmetKey)) continue;

	            var _goalDefinition = _goalState[$ _unmetKey];

	            
	            var _operator = _goalDefinition.comparison;
	            var _targetValue = _goalDefinition.value;
                    
	            var _currentValue = struct_exists(_currentState, _unmetKey) ? _currentState[$ _unmetKey] : 0;
	            var _newValue = _currentValue + _reactionValue;

	            switch (_operator)
	            {
	                case ">=": if (_reactionValue < 0) _hasUndesirableEffect = true; break;
	                case "<=": if (_reactionValue > 0) _hasUndesirableEffect = true; break;
	                case ">":  if (_reactionValue <= 0) _hasUndesirableEffect = true; break;
	                case "<":  if (_reactionValue >= 0) _hasUndesirableEffect = true; break;
	                case "==": if (_goalDefinition == _reactionValue) _hasUndesirableEffect = true; break;
							
	            }
	            
	           

	            if (_hasUndesirableEffect) break;
	        }

	        if (!_hasUndesirableEffect)
	        {
	            array_push(_filteredActions, _actName);
	        }
	    }

	    return _filteredActions;
	}

	

	function getPositiveReactionsFromAction(action)
	{
	    var effects = action.reactions;
	    var positive = [];

	    // You might already structure reactions as a map of key → value.
	    // We treat all keys set in `reactions` as positive effects for RPG.
	    var keys = struct_get_names(effects);
	    for (var i = 0; i < array_length(keys); i++)
		{
	        var key = keys[i];
			
			var _react = effects[$ key];
			
			if (_react > 0) array_push(positive, key);
			
	        
	    }

	    return positive;
	}

	function getNegativeReactionsFromAction(action)
	{
	    var effects = action.reactions;
	    var negative = [];

	    // You might already structure reactions as a map of key → value.
	    // We treat all keys set in `reactions` as positive effects for RPG.
	    var keys = struct_get_names(effects);
	    for (var i = 0; i < array_length(keys); i++)
		{
	        var key = keys[i];
			
			var _react = effects[$ key];
			
			if (is_bool(_react) and _react == 0)
			{
				array_push(negative, key);
			}
			else if (_react < 0)
			{
				array_push(negative, key);
			}
	        
	    }

	    return negative;
	}
	
	sortActionsByScore = function(_collectedActs, _goalState)
	{
		var action_scores = [];

		for (var i = 0; i < array_length(_collectedActs); ++i)
		{
			var action = _collectedActs[i];
				
			var _act = allActions[$ action];
				
			var effects = _act.reactions; // Assume this is a ds_map

			var _score = 0;
			var keys = struct_get_names(effects);
			for (var k = 0; k < array_length(keys); ++k)
			{
			    var key = keys[k];

			    // Exact match (key and value) is best
			    if (struct_exists(_goalState, key))// && struct_get(_goalState, key) == struct_get(effects, key))
				{
			        _score += 3;
			    }
			    // Partial match (key only) is still useful
			    else if (struct_exists(_goalState, key))
				{
			        _score += 1;
			    }
			}

			if (_score >= 0)
			{
				array_push(action_scores, { name: action, score: _score });
				//show_debug_message($"Sorted: {action} , Score: {_score}");
			}
				
			//array_push(action_scores, {name: action, score: _score});
		}


		array_sort(action_scores, function(a,b)
		{
			return (a.score < b.score);
			
		});
			
		//show_debug_message($"action_scores: {action_scores}");
			
		var _tempActs = [];
		for(var i=0; i<array_length(action_scores); i++)
		{
			var _act = action_scores[i];
			array_push(_tempActs, _act.name);
		}
		
		return _tempActs;
			
	}


	
	function trimActionsToUnmet(relevantActions, unmetKeys)
	{
		var actionSet = {};
	
		// For each unmet condition key, look up actions that can produce it
		for (var i = 0; i < array_length(unmetKeys); i++)
		{
			var key = unmetKeys[i];
		
			if (reactionGraph[$ key] != undefined)
			{
				var producers = reactionGraph[$ key];
			
				for (var j = 0; j < array_length(producers); j++)
				{
					var act = producers[j];
					struct_set(actionSet, act, act);
				}
			}
		}
	
		// Only include relevant actions that appear in the producer set
		var trimmed = [];
		for (var i = 0; i < array_length(relevantActions); i++)
		{
			var actName = relevantActions[i];
			if (struct_exists(actionSet, actName))
			{
				array_push(trimmed, actName);
			}
		}
		
		//show_debug_message($"Trimmed to {array_length(trimmed)} <- from: {array_length(relevantActions)}, Relevant actions: {trimmed}");
		return trimmed;
	}

	

	#endregion
	

	#region		--- Other A* Functions
	
	// --- Simulate applying an action's reactions to a state ---
    function simulateReactions(_state, _reactions)
    {
		//show_debug_message("simulating");
		
        //var new_state = copyStruct(_state); // Start with a copy of the current state
        var new_state = variable_clone(_state); // Start with a copy of the current state
        var reaction_keys = struct_get_names(_reactions);

        for (var i = 0; i < array_length(reaction_keys); i++)
        {
            var key = reaction_keys[i];
            var reaction_value = _reactions[$ key];

            // Check if the state variable exists before attempting to modify it
            // If the reaction is to add a new state variable, add it.
            if (!struct_exists(new_state, key))
			{
                 new_state[$ key] = reaction_value;
                 planLog.logDebug($"Simulating Reaction: Added new key '{key}' with value '{string(reaction_value)}'");
                 continue; // Move to the next reaction
            }

            // --- CORRECTED LOGIC FOR APPLYING REACTIONS ---
            // Prioritize setting boolean values if the reaction value is a boolean.
            if (is_bool(reaction_value))
            {
                 new_state[$ key] = reaction_value; // Direct assignment for booleans
                 planLog.logDebug($"Simulating Reaction: Key '{key}' set to boolean '{string(reaction_value)}'.");
            }
            // Handle numerical changes (+N, -N) ONLY if the reaction value is numeric AND the state value is numeric
            else if (is_numeric(reaction_value) && is_numeric(new_state[$ key]))
            {
                new_state[$ key] += reaction_value; // Apply the numerical change (add or subtract)
                planLog.logDebug($"Simulating Reaction: Key '{key}' numerical change by {string(reaction_value)}. New value: {string(new_state[$ key])}");
            }
            // For all other cases (strings, or numbers for non-numeric state properties, or direct number assignments),
            // treat it as a direct SET value.
            else
            {
                 new_state[$ key] = reaction_value; // Direct assignment
                 planLog.logDebug($"Simulating Reaction: Key '{key}' set to '{string(reaction_value)}'.");
            }


        }
        return new_state;
    }
	
	
	function simulateReactionsWithCache(_currentState, _reactions) 
	{
	    // Create cache key from state and reactions
	    var stateHash = hashState(_currentState);
	    var reactionsHash = hashState(_reactions);
	    var cacheKey = stateHash + "::" + reactionsHash;
    
	    // Check cache first
	    if (struct_exists(simulation_cache, cacheKey)) 
	    {
	        show_debug_message("Sim cache hit");
	        return simulation_cache[$ cacheKey];
	    }
		
		show_debug_message("Sim cache miss");
	    // Cache miss - compute simulation
	    var simState = simulateReactions(_currentState, _reactions);
    
	    // Cache the result
	    simulation_cache[$ cacheKey] = simState;
    
	    return simState;
	}
	

	function state_meets_goal(sim_state, goal_state)
	{
	    var _goal_keys = struct_get_names(goal_state);
	    for (var i = 0; i < array_length(_goal_keys); i++)
		{
	        var _key = _goal_keys[i];
	        if (!keyMatches(sim_state, goal_state, _key))
			{
	            return false; // Early exit if any condition fails
	        }
	    }
	    return true; // All conditions passed
	}


	// Eats up Time during planning(ms)
	ancestorHasState = function(node, new_state)
	{
	    var new_key = hashState(new_state);
		//show_debug_message("----------------------------------");
	    while (node != undefined && node != noone)
	    {
	        var node_key = hashState(node.state);
			
			//show_debug_message($"New Key: {new_key}");
			//show_debug_message($"Node Key: {node_key}");
			
	        if (node_key == new_key)
	        {
	            return true;
	        }
	        node = node.parent;
	    }

	    return false;
	}
	
	
	// Reconstructs the plan from the goal node by walking back through parents
	reconstructPlan = function(_node)
	{
		var plan = [];
		while (_node.parent != undefined)
		{
			array_insert(plan, 0, _node.action); // insert action at beginning
			_node = _node.parent;
		}
		return plan;
		//return array_reverse(plan);
	}

	
	isHelpfulAction = function(_reactions, _unmetKeys)
	{
		var _r = struct_get_names(_reactions);
		for(var i=0; i<array_length(_r); i++)
		{
			var _key = _r[i];
	        if (array_contains(_unmetKeys, _key)) return true;
	    }
	    return false;
	}
	
	#endregion
	

	#endregion
	
	
	#region		---{ Node Stuff }---
	
	
	nodeData = {
		pruned: 0,
		expanded: 0,
		stale: 0,
		actionsTried: 0,
		accumulatedHeuristic: 0,
	}


	resetNodeData = function()
	{
		nodeData.pruned = 0;
		nodeData.expanded = 0;
		nodeData.stale = 0;
		nodeData.actionsTried = 0;
		nodeData.accumulatedHeuristic = 0;
	}


	reportNodeData = function(_planLength, _bestGoalNode)
	{
		
		
		/*
			Summary of all Node DATA
			
				If Prune Ratio goes up, you’re cutting out more useless nodes early, which is good.
				If Efficiency (expanded/total) increases, you’re expanding a higher portion of relevant nodes, also good.
				If Branching Factor drops, your planner is focusing more tightly on promising paths.
				If Goal Efficiency improves, more of your expansions are actually contributing to the final plan.
		*/
		
		var _showData = true;
		var _showSimpleData = true;
		
		
		if !_showData return;
		
		var _truePruned = nodeData.pruned;
		var _totalNodes = _truePruned + nodeData.expanded;

		var _pruneRatio = 0;
		var _expansionEfficiency = 0;
		var _branchingFactor = 0;
		var _goalEfficiency = 0;
		var _reExpansionRate = 0;
		var _avgHeuristicRate = 0;		// the average hCost of the nodes that A* expanded.
		var _planGCost = _bestGoalNode.gCost;
		
		var _optimalPathNodes = _planLength + 1;
		var _extraExpandedNodes = nodeData.expanded - _optimalPathNodes
		
		var _expansionOverheadRatio = 0;	// for every 1 node on the optimal path, your A* had to expand nearly # nodes
		
		/*
		
			A ratio closer to 1 (or within a reasonable range) suggests the average heuristic value is a good proportion of the total cost.
			A very low ratio might suggest an under-informed heuristic (if _planGCost is high).
			A very high ratio might suggest an overly optimistic or aggressive heuristic
			(though still admissible, it might mean the hCost values are large compared to the actual path cost increments).
		
		*/
		
		var _heuristicCostRatio = 0;

		if (_totalNodes > 0)
		{
			_pruneRatio = _truePruned / _totalNodes;
			_expansionEfficiency = nodeData.expanded / _totalNodes;
		}

		if (_planLength > 0)
		{
			_branchingFactor = nodeData.actionsTried / nodeData.expanded;
		}

		if (nodeData.expanded > 0)
		{
			_goalEfficiency = 1 - ((nodeData.expanded - _planLength) / nodeData.expanded);
			_reExpansionRate = nodeData.stale / nodeData.expanded;
			_avgHeuristicRate = nodeData.accumulatedHeuristic / nodeData.expanded; 
			
		}
		
		if (_planGCost > 0)
		{
			_heuristicCostRatio = _avgHeuristicRate / _planGCost;
		}
		
		
		if (_optimalPathNodes > 0)
		{
			_expansionOverheadRatio = _extraExpandedNodes / _optimalPathNodes;
		}
		
		
		
		
		if _showSimpleData
		{
			show_debug_message("--- GOAP Planner Performance Report ---");
			show_debug_message($"Node Data: [Total: {_totalNodes}, Pruned: {_truePruned}, Expanded: {nodeData.expanded}, Stale: {nodeData.stale}, Prune Ratio: {_pruneRatio}]");
		    show_debug_message($"Node Data: [Efficiency: {_expansionEfficiency}, Branching: {_branchingFactor}, Goal Efficiency: {_goalEfficiency}]");
		    show_debug_message($"Node Data: [Re-Expansion Rate: {_reExpansionRate}, Average Heuristic Rate: {_avgHeuristicRate}, Plan G-Cost: {_planGCost}]");
			show_debug_message($"Node Data: [Heuristic Cost Ratio: {_heuristicCostRatio}, Extra Nodes Expanded: {_extraExpandedNodes}, Excess Node Expansion Ratio: {_expansionOverheadRatio}]");
			show_debug_message("-------------------------------------");
		}
		else
		{
			// --- Debug Messages (Sentence Format) ---
		    
	        show_debug_message("--- GOAP Planner Performance Report ---");
	        show_debug_message($"Total nodes considered (including pruned and expanded): {_totalNodes}.");
	        show_debug_message($"Nodes effectively pruned (conditions not met or inferior path): {_truePruned}.");
	        show_debug_message($"Nodes expanded for search: {nodeData.expanded}.");
	        show_debug_message($"Nodes that were stale (re-expanded via a better path): {nodeData.stale}.");
	        show_debug_message($"The prune ratio is {string_format(_pruneRatio, 0, 2)}. (This means {string_format(_pruneRatio * 100, 0, 0)}% of nodes were discarded early).");
	        show_debug_message($"The search efficiency is {string_format(_expansionEfficiency, 0, 2)}. (Meaning {string_format(_expansionEfficiency * 100, 0, 0)}% of considered nodes were expanded).");
	        show_debug_message($"The average branching factor (actions considered per expanded node) is {string_format(_branchingFactor, 0, 2)}.");
	        show_debug_message($"Goal efficiency (how much expanded nodes directly contributed to path) is {string_format(_goalEfficiency, 0, 4)}. (Meaning {string_format(_goalEfficiency * 100, 0, 1)}% of expanded nodes were on the optimal path).");
	        show_debug_message($"The re-expansion rate is {string_format(_reExpansionRate, 0, 2)}. (This highlights {string_format(_reExpansionRate * 100, 0, 0)}% wasted work due to re-expanding states).");
	        show_debug_message($"The average heuristic estimate for expanded nodes was {string_format(_avgHeuristicRate, 0, 2)}.");
	        show_debug_message($"The final plan's total G-Cost is {_planGCost}.");
	        show_debug_message($"The Heuristic Cost Ratio is {string_format(_heuristicCostRatio, 0, 2)}. (This indicates your heuristic's estimate strength is {string_format(_heuristicCostRatio * 100, 0, 0)}% of the total plan cost).");
	        show_debug_message($"The number of nodes on the optimal path (including start) is {_optimalPathNodes}.");
	        show_debug_message($"Extra nodes expanded (not on the optimal path) are: {_extraExpandedNodes}.");
	        show_debug_message($"The Excess Node Expansion Ratio is {string_format(_expansionOverheadRatio, 0, 2)}. (For every optimal node, {string_format(_expansionOverheadRatio, 0, 2)} extra nodes were expanded).");
	        show_debug_message("-------------------------------------");
			
		}
		
		
		resetNodeData();
	}


	
	
	function astarNode(_state, _action, _parent, _gCost, _hCost) constructor
	{
		state = _state;
		action = _action;
		parent = _parent;
		gCost = _gCost;
		hCost = _hCost;
		fCost = gCost + hCost;
	}
	
	
	#endregion	
	
	#region		--- Sub Goal Stuff ---
	
	function buildSubGoals(_startState, _goalState)
	{
	    var keys = struct_get_names(_goalState);
	    var subgoalInfo = []; // [{ goal: {}, unmet: [...], category: string }]

	    // Step 1: Break into atomic subgoals and get unmet conditions, categorize them
	    for (var i = 0; i < array_length(keys); i++)
		{
		    var key = keys[i];
		    var singleGoal = {};
		    singleGoal[$ key] = _goalState[$ key];
		    var unmet = getUnmetNonExplicitConditions(singleGoal, _startState);
        
		    var category = "Other"; // Default category

		    var goalValue = _goalState[$ key];
		    if (is_bool(goalValue)) {
		        if (goalValue == true) {
		            // Goals like "HasWeapon: true", "HasPowerGenerator: true"
		            // These are often foundational items/structures that unlock other capabilities.
		            category = "AcquireBooleanTrue"; 
		        } else { // goalValue == false
		            // Goals like "WeaponNeedsRepair: false", "GeneratorNeedsMaintenance: false"
		            // These typically represent maintenance or state correction.
		            category = "CorrectBooleanFalse";
		        }
		    } else if (is_struct(goalValue) && struct_exists(goalValue, "value") && is_numeric(goalValue.value)) {
		        // Numerical conditions, e.g., "Ammo: >= 10", "Scrap: >= 25", "Energy: >= 100"
		        // These often represent resource accumulation or threshold achievement.
		        category = "AchieveNumericalThreshold";
		    }
		    // If there are other complex types, they'd fall into "Other" or get new categories here.

		    array_push(subgoalInfo, { 
		        goal: singleGoal, 
		        unmet: unmet, 
		        category: category
		    });
		}

		// Step 2: Initial Grouping by Shared Unmet Keys
		// This step combines subgoals that naturally depend on the same preconditions.
		var groups = [];
		for (var i = 0; i < array_length(subgoalInfo); i++)
		{
		    var current = subgoalInfo[i];
		    var merged = false;
		    for (var j = 0; j < array_length(groups); j++)
		    {
		        var group = groups[j];
		        var overlap = false;
		        for (var k = 0; k < array_length(current.unmet); k++)
		        {
		            var key = current.unmet[k];
		            if (array_contains(group.unmetSet, key))
		            {
		                overlap = true;
		                break;
		            }
		        }
		        if (overlap)
		        {
		            deepMergeStructs(group.goal, current.goal);
		            group.unmetSet = array_union(group.unmetSet, current.unmet);
		            // When merging, if any part of the merged group was a specific category,
		            // the merged group inherits that "stronger" category for sorting purposes.
		            // This logic might need refinement based on desired merge behavior.
		            // For simplicity here, if the current item is a specific category, it takes precedence.
		            if (current.category != "Other") {
		                group.category = current.category;
		            }
		            merged = true;
		            break;
		        }
		    }
		    if (!merged)
		    {
		        array_push(groups, {
		            goal: current.goal,
		            unmetSet: variable_clone(current.unmet),
		            category: current.category
		        });
		    }
		}
		show_debug_message($" Step 2: Groups ({array_length(groups)}): {groups}");
		
		// --- Step 3: Aggressive/Strategic Combination ---
	    var combinedGroups = [];
	    var processedIndices = array_create(array_length(groups)); // Track which groups have been processed

	    for (var i = 0; i < array_length(groups); i++) {
	        if (processedIndices[i]) continue;

	        var currentGroup = groups[i];
	        var mergedThisIteration = false;

	        // Strategy 1: Combine all "AchieveNumericalThreshold" goals that are still unmet.
	        // This is a common pattern where accumulating one resource (money) helps another (seeds, water).
	        if (currentGroup.category == "AchieveNumericalThreshold" && array_length(currentGroup.unmetSet) > 0) {
	            var tempCombinedGoal = variable_clone(currentGroup.goal);
	            var tempCombinedUnmet = variable_clone(currentGroup.unmetSet);
	            var combinedCount = 1;

	            for (var j = i + 1; j < array_length(groups); j++) {
	                if (processedIndices[j]) continue;

	                var otherGroup = groups[j];
	                if (otherGroup.category == "AchieveNumericalThreshold" && array_length(otherGroup.unmetSet) > 0) {
	                    deepMergeStructs(tempCombinedGoal, otherGroup.goal);
	                    tempCombinedUnmet = array_union(tempCombinedUnmet, otherGroup.unmetSet);
	                    processedIndices[j] = true;
	                    combinedCount++;
	                }
	            }

	            if (combinedCount > 1) { // If actual merging happened
	                array_push(combinedGroups, {
	                    goal: tempCombinedGoal,
	                    unmetSet: tempCombinedUnmet,
	                    category: "AchieveNumericalThreshold" // Maintain category
	                });
	                processedIndices[i] = true; // Mark the original group as processed
	                mergedThisIteration = true;
	                show_debug_message($" Strategically combined {combinedCount} 'AchieveNumericalThreshold' goals.");
	            }
	        }
        
	        // If not merged by Strategy 1, or if it was processed, just add it.
	        if (!mergedThisIteration && !processedIndices[i]) {
	            array_push(combinedGroups, variable_clone(currentGroup));
	            processedIndices[i] = true;
	        }
	    }
	    groups = combinedGroups; // Update 'groups' for the next step
	    show_debug_message($" Step 3: Strategically Combined Groups ({array_length(groups)}): {groups}");

		
		// --- Step 3.5: Combine all groups with empty unmetSet into a single group ---
		var combinedEmptyUnmetGoal = {};
		var newGroups = [];
		var emptyUnmetFound = false;

		for (var i = 0; i < array_length(groups); i++) {
		    if (array_length(groups[i].unmetSet) == 0) {
		        // Merge goals from empty unmetSet groups
		        deepMergeStructs(combinedEmptyUnmetGoal, groups[i].goal);
		        emptyUnmetFound = true;
		    } else {
		        // Keep groups with unmet conditions as-is
		        array_push(newGroups, groups[i]);
		    }
		}

		if (emptyUnmetFound) {
		    array_push(newGroups, {
		        goal: combinedEmptyUnmetGoal,
		        unmetSet: [],
		        category: "Other" // or pick appropriate category
		    });
		}

		groups = newGroups; // Replace old groups with new merged set

		show_debug_message($" Step 3.5: Combined Empty Unmet Groups (Total Groups Now: {array_length(groups)})");

		// --- Step 3.75: Merge all simple goals into one "main" goal group ---
		//var complexGroups = [];
		//var combinedSimpleGoal = {};
		//var simpleFound = false;

		//for (var i = 0; i < array_length(groups); i++) {
		//    var group = groups[i];
		//    var isSimple = false;

		//    // Define your simplicity criteria:
		//    if (array_length(group.unmetSet) <= 1 && array_length(struct_get_names(group.goal)) <= 1) {
		//        isSimple = true;
		//    }

		//    // Or: also consider unmetSet empty (already satisfied)
		//    if (array_length(group.unmetSet) == 0) {
		//        isSimple = true;
		//    }

		//    if (isSimple) {
		//        deepMergeStructs(combinedSimpleGoal, group.goal);
		//        simpleFound = true;
		//    } else {
		//        array_push(complexGroups, group);
		//    }
		//}

		//// Push merged simple goal group if found
		//if (simpleFound) {
		//    array_push(complexGroups, {
		//        goal: combinedSimpleGoal,
		//        unmetSet: getUnmetNonExplicitConditions(combinedSimpleGoal, _startState),
		//        category: "Other" // Or keep most common category among merged ones
		//    });
		//}

		//groups = complexGroups;
		//show_debug_message($" Step 3.75: Merged simple goals. Total Groups Now: {array_length(groups)}");


		// After Step 3.5, where empty-unmet groups have already been merged into a single one (if any)
		//var emptyGroup = undefined;
		//var newGroups = [];

		//for (var i = 0; i < array_length(groups); i++) {
		//    if (array_length(groups[i].unmetSet) == 0) {
		//        emptyGroup = groups[i];
		//    } else {
		//        array_push(newGroups, groups[i]);
		//    }
		//}

		//if (emptyGroup != undefined && array_length(newGroups) > 0) {
		//    // Merge emptyGroup's goal into the first non-empty group
		//    deepMergeStructs(newGroups[0].goal, emptyGroup.goal);
		//    newGroups[0].category = "Other"; // Optional: flatten category if mixing goal types
		//    show_debug_message(" Step 3.75: Merged simple goals. Total Groups Now: " + string(array_length(newGroups)));
		//} else {
		//    newGroups = groups; // No change needed
		//}
		//groups = newGroups;

		// After Step 3.5 – assume `groups` is your current group list
		var mergedGroups = [];
		var singletonGoals = [];

		for (var i = 0; i < array_length(groups); i++) {
		    var goalKeys = struct_get_names(groups[i].goal);
		    if (array_length(goalKeys) == 1) {
		        // Consider this a singleton subgoal
		        array_push(singletonGoals, groups[i]);
		    } else {
		        array_push(mergedGroups, groups[i]);
		    }
		}

		// Merge each singleton goal into the first multi-goal group (or keep separate if none)
		for (var i = 0; i < array_length(singletonGoals); i++) {
		    var singleGroup = singletonGoals[i];

		    // Prefer merging into the group with the fewest unmet keys (greedy heuristic)
		    var bestIndex = -1;
		    var minUnmet = 99999;

		    for (var j = 0; j < array_length(mergedGroups); j++) {
		        var unmetCount = array_length(mergedGroups[j].unmetSet);
		        if (unmetCount < minUnmet) {
		            minUnmet = unmetCount;
		            bestIndex = j;
		        }
		    }

		    if (bestIndex != -1) {
		        deepMergeStructs(mergedGroups[bestIndex].goal, singleGroup.goal);
		        mergedGroups[bestIndex].unmetSet = array_union(mergedGroups[bestIndex].unmetSet, singleGroup.unmetSet);
		        mergedGroups[bestIndex].category = "Other"; // Optional: flatten category
		    } else {
		        // No other group to merge into, keep as its own
		        array_push(mergedGroups, singleGroup);
		    }
		}

		groups = mergedGroups;
		show_debug_message(" Step 3.75: Merged singleton goals. Total Groups Now: " + string(array_length(groups)));

		
		// Step 4: Dynamic Strategic Sorting of groups
		// This sorting function determines the order in which subgoal groups are tackled.
		array_sort(groups, function(a, b) {
		    // Define a numeric priority for each category. Lower number means higher priority.
		    var categoryPriority = {
		        "AcquireBooleanTrue": 1,        // e.g., Get a weapon, build a generator (foundational)
		        "CorrectBooleanFalse": 2,       // e.g., Repair weapon, maintain generator (state correction)
		        "AchieveNumericalThreshold": 3, // e.g., Get enough ammo, food, energy (resource accumulation)
		        "Other": 4                      // Catch-all for anything else
		    };

		    var a_priority = categoryPriority[$ a.category];
		    var b_priority = categoryPriority[$ b.category];

		    // Priority 1: Category
		    if (a_priority != b_priority) {
		        return a_priority - b_priority;
		    }

		    // Priority 2: Unmet conditions count (fewer unmet is easier to achieve)
		    var a_unmet_count = array_length(a.unmetSet);
		    var b_unmet_count = array_length(b.unmetSet);
		    if (a_unmet_count != b_unmet_count) {
		        return a_unmet_count - b_unmet_count;
		    }
        
		    // Priority 3: Goal complexity (fewer conditions in the group's goal)
		    var a_goal_size = array_length(struct_get_names(a.goal));
		    var b_goal_size = array_length(struct_get_names(b.goal));
		    if (a_goal_size != b_goal_size) {
		        return a_goal_size - b_goal_size;
		    }

		    return 0; // If all ties, maintain original order
		});
    
		var finalGroups = groups; // The sorted 'groups' array is our final result

		show_debug_message($" Final Groups ({array_length(finalGroups)}): {finalGroups}");
    
		return finalGroups;
	}
	
	
	function planSubgoalGroupsSmart(currentState, subgoalGroups, _goalState)
	{
	    var fullPlan = [];
	    var remaining = variable_clone(subgoalGroups);
		var simState = variable_clone(currentState);
    
		var previousRemainingCount = array_length(remaining);
		
	
	    while (array_length(remaining) > 0)
	    {
			
			
			// First, prune any goals that are now met in the simulatedCurrentState
		    var stillRemaining = [];
		    for (var i = 0; i < array_length(remaining); i++) {
		        if (!state_meets_goal(simState, remaining[i].goal)) {
		            array_push(stillRemaining, remaining[i]);
		        } else {
		            show_debug_message($"Goal group already met, removing from remaining: {string(remaining[i].goal)}");
		        }
		    }
		    remaining = stillRemaining; // Update the array

		    if (array_length(remaining) == 0)
			{ // All goals met, exit loop
		        break;
		    }

		    // --- Check for Stagnation ---
		    if (array_length(remaining) > previousRemainingCount) {
		        show_debug_message("Stuck: No progress made on remaining goals in the last iteration. Returning partial plan.");
		        return fullPlan; // Return the plan accumulated so far
		    }
		    previousRemainingCount = array_length(remaining);
			
			
			
	        var plannedThisIteration = false;
        
	        for (var i = 0; i < array_length(remaining); i++)
	        {
	            var group = remaining[i];
	            if (state_meets_goal(simState, group.goal))
	            {
	                array_delete(remaining, i, 1);
	                i--;
	                continue;
	            }
            
	            var plan = findPlan(simState, group.goal);
	            if (array_length(plan) > 0)
	            {
	                simState = applyPlanToState(simState, plan);
	                fullPlan = array_concat(fullPlan, plan);
	                array_delete(remaining, i, 1);
	                i--;
	                plannedThisIteration = true;
	            }
	        }
        
	        if (!plannedThisIteration)
	        {
	            // Combine all remaining subgoal goals into one goal struct
				var combinedGoal = {};
				for (var i = 0; i < array_length(remaining); i++) {
				    deepMergeStructs(combinedGoal, remaining[i].goal);
				}
				
				show_debug_message($"combinedGoal: {combinedGoal}")
				show_debug_message($"simState: {simState}")

				var combinedPlan = findPlan(simState, combinedGoal);
				if (array_length(combinedPlan) > 0) {
				    simState = applyPlanToState(simState, combinedPlan);
				    fullPlan = array_concat(fullPlan, combinedPlan);
				    remaining = [];
				} else {
				    show_debug_message("Failed to plan combined remaining subgoals. Returning partial plan.");
				    break;
				}

	        }
	    }
    
	    // Final smoothing: plan any leftover gaps to reach full goal
	    if (!state_meets_goal(simState, _goalState))
	    {
	        show_debug_message("Smoothing remaining unmet goal conditions...");
			
	        var smoothingPlan = findPlan(simState, _goalState);
	        simState = applyPlanToState(simState, smoothingPlan);
	        fullPlan = array_concat(fullPlan, smoothingPlan);

	        if (state_meets_goal(simState, _goalState))
	            show_debug_message("Final smoothed plan meets the goal.");
	        else
	            show_debug_message("Warning: Final smoothed plan still does not meet the goal.");
				
			show_debug_message($"Current Sim State: {simState}");
	    }
	    else
	    {
	        show_debug_message("Final plan meets the goal without smoothing.");
	    }
    
	    return fullPlan;
	}

	#endregion
	

	function applyPlanToState(state, plan)
	{
	    var sim = variable_clone(state);
	    for (var i = 0; i < array_length(plan); i++) {
	        sim = simulateReactions(sim, allActions[$ plan[i]].reactions);
	    }
	    return sim;
	}


	// if you feed a large goal into this it will take a long ass time
	///@desc Creating the plan, the CORE of GOAP.
	function findPlan(_startState, _goalState)
	{
		
		#region	<Init Vars>
		
		var _startMS = current_time;
		
		
		// cached data
		var _visitedNodes = {};				// stateHash -> best node
		var _stateActionsMap = {};			// track actions tried on each state (state hash -> struct of action names)
		
		var _relevantActionsCache = {};  // cacheKey -> filtered actions array
		
		
		var _currentBound = infinity;
		
		var _nonDeterministic = false;		// can lower speed of the planner
		
		var _open = ds_priority_create();
		
		var _bestFSoFar = infinity; // Large initial value
		var _bestGoalNode = noone;
		
		
		var _finalPlan = [];
		
		
		var _startHash = hashState(_startState);
		var _goalStateHash = hashState(_goalState);
		
		
		var _startNode = new astarNode(_startState, undefined, undefined, 0, calculateHeuristic(_startState, _goalState, _startHash, _goalStateHash, getAllUnmetConditions(_goalState, _startState)));
		//var _startNode = new astarNode(_startState, undefined, undefined, 0, calculateHeuristic(_startState, _goalState, _startHash, _goalStateHash, []));
		
		
		struct_set(_visitedNodes, _startHash, _startNode);
		ds_priority_add(_open, _startNode, _startNode.fCost);

		
		
		#endregion
		
		var _printEvery = false;
		
		//show_debug_message($"Target GOAL: {targetGoal}");
		
		//show_debug_message($"Goal State: {_goalState}");
		//show_debug_message($"Start State: {_startState}");
		
		
		
		// A* Pathfinding from _startState -> _goalState
		while (!ds_priority_empty(_open))
		{
			
			#region		--- Init ---
			
			var _node = ds_priority_delete_min(_open);
			
			
			// Early termination: if best goal found and next node's fCost is >= best goal fCost, break
		    if (_bestGoalNode != noone && _node.fCost >= _bestFSoFar) break; // no better solution 
			
			
			var _currentState = _node.state;
			var _currentAction = _node.action;
			var _stateHash = hashState(_currentState);
			
			
			#endregion
			
			
			var _bestOldNode = _visitedNodes[$ _stateHash];
			if (_bestOldNode != _node) continue;
			
			
			nodeData.expanded++;
			

			#region		--- Dynamic Action Filtering ---
			
			
			var _startFil = current_time;
			
			var _unmetGoalKeys = getAllUnmetConditions(_goalState, _currentState);
			var _collectedActs;
			
			// Same unmet goal patterns should produce same relevant actions
			var _goalPatternKey = string(_unmetGoalKeys); // Convert array to string
			
			if (struct_exists(_relevantActionsCache, _goalPatternKey))
			{
				//show_debug_message("Cache Hit for Relevant Actions.");
			    _collectedActs = _relevantActionsCache[$ _goalPatternKey];
			} else {
			    _collectedActs = collectRelevantActions(_unmetGoalKeys);
			    _collectedActs = trimActionsToUnmet(_collectedActs, _unmetGoalKeys);
				_collectedActs = filterActionsByNegativeEffects(_collectedActs, _currentState, _unmetGoalKeys, _goalState);
				_collectedActs = sortActionsByScore(_collectedActs, _goalState);
				
			    struct_set(_relevantActionsCache, _goalPatternKey, _collectedActs);
			}
			
			
			
			// makes it run slightly slower
			//show_debug_message($"Filtered Actions ({array_length(_collectedActs)}): {_collectedActs}");
			
			
			
			var _endTimeFil = current_time - _startFil;
			if (_printEvery) and (_endTimeFil > 0) show_debug_message($"Filter Actions: {_endTimeFil} ms");
			
			#endregion
			
			nodeData.accumulatedHeuristic += _node.hCost;
			
			
			#region		--- Expand all relavant actions ---
			
			var _startExp = current_time;
			
			
			for (var i = 0; i < array_length(_collectedActs); i++)
			{
				var _actName = _collectedActs[i];
				var _act = allActions[$ _actName];
				if (_act == undefined) continue;

				nodeData.actionsTried++; // Count every applicable action per node
				
				
				#region			--- Pruning Before Simulating State ---
				
				
				if (!checkKeysMatch(_act.conditions, _currentState))
				{
					if (_printEvery) show_debug_message($"Action ({_actName}) conditions not met.");
					nodeData.pruned++;
					continue;
				}
				
				//if !isHelpfulAction(_act.reactions, _unmetGoalKeys)
				//{
				//	show_debug_message($"Action ({_actName}) isnt helpful.");
				//	nodeData.pruned++;
				//	continue;
				//}
				
				
				
				#endregion
				
				
				var _simState = simulateReactions(_currentState, _act.reactions);
				var _simHash = hashState(_simState);
				
				//var _simState = simulateReactionsWithCache(_currentState, _act.reactions);
				//var _simHash = hashState(_simState);
				
				
				#region			--- Pruning After Simulating State ---
				
				//if ancestorHasState(_node, _simState)
				//{
				//	show_debug_message("Ancestor Has State.");
				//	nodeData.pruned++;
				//	continue;
				//}
				
				var _hAfter = calculateHeuristic(_simState, _goalState, _simHash, _goalStateHash, _unmetGoalKeys);
				
				// Apply heuristic consistency correction
				var _correctedH = max(_hAfter, _node.hCost - _act.cost);
				var _gCost = _node.gCost + _act.cost;
				var _fCost = _gCost + _correctedH;
				
				
				
				var enqueueNode = false;

				if (struct_exists(_visitedNodes, _simHash))
				{
				    var _existingOldNode = _visitedNodes[$ _simHash];

				    if (_gCost >= _existingOldNode.gCost)
					{
				        nodeData.pruned++;
				        continue;
				    }

				    nodeData.stale++;
				    enqueueNode = true;
				} else {
				    enqueueNode = true;
				}

				if (!enqueueNode) continue;
				

				// Action-set tracking (after dedup)
				if (!struct_exists(_stateActionsMap, _simHash))
				{
				    struct_set(_stateActionsMap, _simHash, {});
				}

				var _actionSet = _stateActionsMap[$ _simHash];
				if (struct_exists(_actionSet, _actName))
				{
				    nodeData.pruned++;
				    continue;
				}

				// Only create the node, after passing all checks
				var _newNode = new astarNode(_simState, _act, _node, _gCost, _correctedH);

				// Enqueue node
				struct_set(_visitedNodes, _simHash, _newNode);
				
				
				var initialWeight = 1//.000002; // put this to 1 to make it non greedy
				var finalWeight = 1.0;

				// Normalize heuristic progress relative to startH
				var progress = clamp(1.0 - (_correctedH / (_startNode.hCost+0.000001)), 0, 1);
				var dynamicWeight = lerp(initialWeight, finalWeight, progress);

				var _priority = _gCost + _correctedH * dynamicWeight;

				
				
				if (_priority > _currentBound)
				{
					//show_debug_message("prune expensive paths beyond bound");
				    nodeData.pruned++;
				    continue;  // prune expensive paths beyond bound
				}
				
				//show_debug_message($"Dynamic Weight: {dynamicWeight}");
				
				//weighted A*
				//var weight = 1.0; // Try values between 1.1 and 3.0
				//var _priority = _gCost + _correctedH * weight; 
				
				
				ds_priority_add(_open, _newNode, _priority);
				struct_set(_actionSet, _actName, true);

				// Check for new best goal
				if (state_meets_goal(_simState, _goalState))
				{
				    if (_fCost < _bestFSoFar)
					{
						//_currentBound = _fCost;  // tighten bound
						_currentBound = min(_currentBound, _fCost);
						
						
				        _bestFSoFar = _fCost;
				        _bestGoalNode = _newNode;
				    }
					
					//show_debug_message("Meets GOAL");
				}

				
				#endregion
				
				//show_debug_message($"Action Made it: {_actName}");
				//show_debug_message($"[{current_time-_startMS} ms] Expanding ({nodeData.expanded}): g={_newNode.gCost}, h={_newNode.hCost}, f={_newNode.fCost}");
				//show_debug_message("--------------------------------------------------");
				
			}
			
			var _endTimeExp = current_time - _startExp;
			if (_printEvery) and (_endTimeExp > 0) show_debug_message($"Expand Relevant Actions: {_endTimeExp} ms");
			
			
			#endregion
			
		}
		
		
		
		// Goal Found.
		if (_bestGoalNode != noone)
		{
			var _plan = reconstructPlan(_bestGoalNode);
			var _pnames = getPlanActionNames(_plan);
			_finalPlan = _pnames;
			var _pLen = array_length(_finalPlan);
			
			// Debugging stuff
			reportNodeData(_pLen, _bestGoalNode);
			
		}
		
		
		return _finalPlan;
	}
	
	
	
	createPlan = function(_startState, _goalState)
	{
		
		//show_debug_message($"Creating Plan started...");
		
	    setupActionData(); // find a better place to put this ltr.

		// --- Check Plan Cache ---
		var _cacheKey = hashState(_startState)+"|"+hashState(_goalState);
		if (struct_exists(plan_cache, _cacheKey))
		{
			var cached_plan = struct_get(plan_cache, _cacheKey);
			planLog.logInfo($"Plan found in cache for state/goal: {_cacheKey}. Using cached plan.");
			return cached_plan; // Return the cached plan immediately
		}
		
		
		var _subMS = current_time;
		
		//show_debug_message($"Goal State: {_goalState}");
		//show_debug_message($"Start State: {_startState}");
		
		
		//var _subGoals = buildSubGoals(_startState, _goalState);
		//show_debug_message($"Sub Goals: {_subGoals}");
		//var _subPlan = planSubgoalGroupsSmart(_startState, _subGoals, _goalState);

		//show_debug_message($"Sub Goal Plan ({array_length(_subPlan)}) in ({current_time - _subMS}) ms: {_subPlan}");
		
		
		var _stMS = current_time; 
		var _entirePlan = findPlan(_startState, _goalState);
		show_debug_message($"Full Plan ({current_time - _stMS} ms)({array_length(_entirePlan)}): {_entirePlan}");
		
		
		struct_set(plan_cache, _cacheKey, _entirePlan);
		
		return _entirePlan;	//	return a array with names of the actions as strings
	}

	
	
}


#region Node Stuff

///@desc Building block for the Goals & Actions of GOAP
function nodeGOAP(_name) constructor
{
	//uuid = "node_"//+generateUUID(8);
	
	name = _name;
	
	conditions = {};
	
	
	showDebug = false; 
	
	
	addCondition = function(_name, _comp, _val)
	{
		if (struct_exists(conditions, _name))
		{
			if showDebug show_debug_message($"Condition ({_name}) Exists Already.");
			return;
		}
		
		struct_set(conditions, _name, {comparison: _comp , value: _val});
		
	}
	
    // convert all switch statements that dont use {comparison: _comp , value: _val} so the 
    // addEualToCondition can be the simple condition
	//addSimpleCondition = function(_name, _val)
	//{
	//	if (struct_exists(conditions, _name))
	//	{
	//		if showDebug show_debug_message($"Condition ({_name}) Exists Already.");
	//		return;
	//	}
		
	//	struct_set(conditions, _name, _val);
	//}
	
	addSimpleCondition = function(_name, _val) { addCondition(_name, "==", _val); }
	addGreaterThanCondition = function(_name, _val) { addCondition(_name, ">", _val); }
	addGreaterThanOrEqualToCondition = function(_name, _val) { addCondition(_name, ">=", _val); }
	addLessThanCondition = function(_name, _val) { addCondition(_name, "<", _val); }
	addLessThanOrEqualToCondition = function(_name, _val) { addCondition(_name, "<=", _val); }
	
	
}




function actionGOAP(_name, _cost) : nodeGOAP(_name) constructor
{
	cost = _cost;
	reactions = {};
	isInterruptible = false;
	
	target = noone;
	targetKey = undefined;
	targetMode = actionTargetModeExecution.none;
	maxInteractionRange = undefined;
	
	executeFunction = undefined;
	
	
	#region		--- Public User Functions
	
	addReaction = function(_name, _val)
	{
		if (struct_exists(reactions, _name))
		{
			if showDebug show_debug_message($"Reaction ({_name}) Exists Already.");
			return;
		}
		
		
		struct_set(reactions, _name, _val);
	}
	
    setExecuteFunction = function(_func)
	{
        executeFunction = _func;  // Set the function that executes the action
    }
	
	setInteractionRange = function(_val)
	{
		maxInteractionRange = _val;
	}
	
	setTarget = function(_targetName, _mode=actionTargetModeExecution.MoveBeforePerforming) // , _maxRange=undefined
	{
		targetKey = _targetName;
		targetMode = _mode;
		//maxTargetRange = _maxRange;
	}
	
	// leave ts off (false)
	canBeInterrupted = function(_val)
	{
		isInterruptible = _val;
	}

	#endregion	
	
    // Function to execute the action
    execute = function()
	{
        if (executeFunction != undefined)
		{
            executeFunction();  // Call the function to execute the action
        }
        
    }
	
}


function goalGOAP(_name, _priority=1) : nodeGOAP(_name) constructor
{
	priority = _priority;
	
	
}


#endregion



#region --- Example

/*


// --- Real World State Variables for the AI ---
// These are the actual stats/flags the AI instance holds
real_has_weapon = false;
real_ammo = 0;
real_scrap = 0; // Start with 0 scrap
real_weapon_needs_repair = false; // Weapon is NOT broken if we don't have one


// Create an instance of the GOAP brain
goap_brain = new brainGOAP();

// --- Define and Register Sensors ---
// Sensor for HasWeapon (boolean)
goap_brain.registerSensor("HasWeapon", function()
{
    return real_has_weapon; // Read the actual boolean stat
});

// Sensor for Ammo (numerical)
goap_brain.registerSensor("Ammo", function()
{
    return real_ammo; // Read the actual numerical stat
});

// Sensor for Scrap (numerical)
goap_brain.registerSensor("Scrap", function()
{
    return real_scrap; // Read the actual numerical stat
});

// Sensor for WeaponNeedsRepair (boolean)
goap_brain.registerSensor("WeaponNeedsRepair", function()
{
    return real_weapon_needs_repair; // Read the actual boolean stat
});


// --- Define Goal ---
// Goal: Have a weapon, enough ammo, and the weapon is NOT broken
var goal_armed_and_ready = new goalGOAP("ArmedAndReady");
// Goal conditions using numerical and simple formats
goal_armed_and_ready.addSimpleCondition("HasWeapon", true);
goal_armed_and_ready.addGreaterThanOrEqualToCondition("Ammo", 10);
goal_armed_and_ready.addSimpleCondition("WeaponNeedsRepair", false); // Goal is NOT needing repair

// Add the goal to the brain
goap_brain.addGoal(goal_armed_and_ready);


// Action: Find Weapon (Cost 10)
var action_find_weapon = new actionGOAP("FindWeapon", 10);
action_find_weapon.addSimpleCondition("HasWeapon", false);
// Reactions: Gain weapon, and it needs repair
action_find_weapon.addReaction("HasWeapon", true);
action_find_weapon.addReaction("WeaponNeedsRepair", true);
// onEntry: Change the real world state
action_find_weapon.setExecuteFunction(function() // Assuming AI instance accessible via 'self' or passed
{
    show_debug_message("AI is finding a weapon...");
    real_has_weapon = true;
    real_weapon_needs_repair = true;
	show_debug_message("AI is has a weapon");
});


// Action: Collect Scrap (Cost 5)
var action_collect_scrap = new actionGOAP("CollectScrap", 5);
// Conditions: None for simplicity in this example
//action_collect_scrap.addLessThanCondition("Scrap", 50);
// Reaction: Gain 15 scrap
action_collect_scrap.addReaction("Scrap", +15);
// onEntry: Change the real world state
action_collect_scrap.setExecuteFunction(function() // Assuming AI instance accessible via 'self' or passed
{
    show_debug_message("AI is collecting scrap...");
    real_scrap += 15; // Add scrap to the real AI stat
    show_debug_message("AI collected scrap. Total scrap: " + string(real_scrap));
});


// Action: Craft Ammo (Cost 8)
var action_craft_ammo = new actionGOAP("CraftAmmo", 8);
// Conditions: Need enough scrap, and need a weapon
action_craft_ammo.addGreaterThanOrEqualToCondition("Scrap", 5);
action_craft_ammo.addSimpleCondition("HasWeapon", true);
// Reactions: Spend 5 scrap, gain 10 ammo
action_craft_ammo.addReaction("Scrap", -5);
action_craft_ammo.addReaction("Ammo", +10);
// onEntry: Change the real world state
action_craft_ammo.setExecuteFunction(function()
{
    show_debug_message("AI is crafting ammo...");
    real_scrap -= 5; // Deduct scrap from real AI stat
    real_ammo += 10; // Add ammo to real AI stat
	show_debug_message($"AI crafting ammo: Scrap: {real_scrap}, Ammo: {real_ammo}");
    show_debug_message("AI crafted ammo. Scrap: " + string(real_scrap) + ", Ammo: " + string(real_ammo));
});


// Action: Repair Weapon (Cost 12)
var action_repair_weapon = new actionGOAP("RepairWeapon", 12);
// Conditions: Weapon needs repair, need enough scrap, need a weapon
action_repair_weapon.addSimpleCondition("WeaponNeedsRepair", true);
action_repair_weapon.addGreaterThanOrEqualToCondition("Scrap", 10);
action_repair_weapon.addSimpleCondition("HasWeapon", true);
// Reactions: Spend 10 scrap, weapon no longer needs repair
action_repair_weapon.addReaction("Scrap", -10);
action_repair_weapon.addReaction("WeaponNeedsRepair", false);
// onEntry: Change the real world state
action_repair_weapon.setExecuteFunction(function()
{
    show_debug_message("AI is repairing weapon...");
    real_scrap -= 10; // Deduct scrap from real AI stat
    real_weapon_needs_repair = false; // Set weapon as repaired
    show_debug_message("AI repaired weapon. Scrap: " + string(real_scrap) + ", Needs Repair: " + string(real_weapon_needs_repair));
});


// Add actions to the brain
goap_brain.addActionsByArray([
    action_find_weapon,
    action_collect_scrap,
    action_craft_ammo,
    action_repair_weapon
]);


// --- Set the Target Goal ---
goap_brain.setTargetGoal("ArmedAndReady");

show_debug_message("Starting GOAP brain with 'Get Armed' goal...");
goap_brain.generatePlan();
// In your Step event, you would then call goap_brain.runPlan();

*/

#endregion


