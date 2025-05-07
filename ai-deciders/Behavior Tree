


function BehaviorTree() constructor
{
	
	rootNode = undefined;
	
	showType = false;
	
	setRootNode = function(_rootNode)
	{
		rootNode = _rootNode;
	}
	
	run = function()
	{
		if rootNode == undefined return;
		rootNode.run();
	}
	
	_internalPrintTree = function(_node, _prefix, _isLast)
	{
		
	    // Draw the branch
	    var branch = _isLast ? "└── " : "├── ";
		
		if showType
		{
			show_debug_message($"{_prefix}{branch}[{_node.name}] ({node_to_string(_node.nodeType)})");
		} else {
			show_debug_message($"{_prefix}{branch}[{_node.name}]");
		}
	    

	    // If this node has children
	    if (variable_instance_exists(_node, "children") && is_array(_node.children))
	    {
	        var _count = array_length(_node.children);
	        for (var i = 0; i < _count; i++)
	        {
	            var _child = _node.children[i];
	            var _childIsLast = (i == _count - 1);

	            // Build new prefix for the child
	            var _childPrefix = _prefix + (_isLast ? "    " : "│   ");

	            _internalPrintTree(_child, _childPrefix, _childIsLast);
	        }
	    }
	}
	
	
	printTree = function(_node)
	{
	    
		show_debug_message("Printing BT Tree");
	    // Start recursion at root
	    _internalPrintTree(_node, "", true);
	}

	

}


enum BTstatus {
	SUCCESS,
	FAILURE,
	
}
	
 
enum NodeType {
	blank,
	root,
	action,
	condition,
	selector,
	sequence,
	parallel,
}



function bool_to_string(_bool)
{
	if _bool
	{
		return "True";
	} else {
		return "False";
	}
	 
}

function node_to_string(_nodeType)
{
	var _str = "";
	switch(_nodeType)
	{
		case NodeType.blank: _str="blank" break;
		case NodeType.root: _str="root" break;
		case NodeType.action: _str="action" break;
		case NodeType.condition: _str="condition" break;
		case NodeType.selector: _str="selector" break;
		case NodeType.sequence: _str="sequence" break;
		case NodeType.parallel: _str="parallel" break;
	}
	
	return _str;
}



function nodeBT(_name="node") constructor
{
	
	name = _name;
	nodeType = NodeType.root;
	
	showDebug = false;
	
	setName = function(_name)
	{
		name = _name;
	}
	
	
	run = function()
	{
		show_debug_message("This needs to be overriden.");
	}
	
}

function actionNodeBT(_name, _action) : nodeBT(_name) constructor
{
	action = _action;
	
	nodeType = NodeType.action;
	
	run = function()
	{
		var _val = action();
		if showDebug show_debug_message($"Performing Action {name}: {bool_to_string(_val)}");
		
		return BTstatus.SUCCESS;
		//return BTstatus.FAILURE;
		
	}
}

function conditionNodeBT(_name, _condition) : nodeBT(_name) constructor
{
	condition = _condition;
	
	nodeType = NodeType.condition;
	
	run = function()
	{
		var _val = condition();
		if showDebug show_debug_message($"Checking Condition {name}: {bool_to_string(_val)}");
		
		if _val return BTstatus.SUCCESS;
		return BTstatus.FAILURE;
		
	}
}



#region Composite Nodes

function compositeNodeBT(_name, _children) : nodeBT(_name) constructor
{
	
	
	children = _children;
	//child_map = {};
	
	
	addChild = function(_child)
	{
		array_push(children, _child);	
		
	}
	
	
	run = function()
	{
		if showDebug show_debug_message("This needs to be overriden.");
	}
	
}

function chooseRandomNodeBT(_name, _children) : compositeNodeBT(_name, _children) constructor
{
    nodeType = NodeType.selector; // You could also consider making this its own type if you prefer
    
    run = function()
    {
        // Choose one random child from the list
        var randomIndex = irandom(array_length(children) - 1);
        var selectedChild = children[randomIndex];
        if showDebug show_debug_message($"Selected Child: {selectedChild.name}");
		
        // Run the selected random child
        var _result = selectedChild.run();
        
        // Return the result of that child
		return BTstatus.SUCCESS;
    }
}


function selectorNodeBT(_name, _children) : compositeNodeBT(_name, _children) constructor
{
	
	nodeType = NodeType.selector;
	
	run = function()
	{
		for(var c=0; c<array_length(children); c++)
		{
			var _child = children[c];
			var _result = _child.run();
			
			if _result == BTstatus.SUCCESS
			{
				return BTstatus.SUCCESS;
			}
			
		}
		
		return BTstatus.FAILURE;
		
	}
}

function sequenceNodeBT(_name, _children) : compositeNodeBT(_name, _children) constructor
{
	
	nodeType = NodeType.sequence;
	
	run = function()
	{
		for(var c=0; c<array_length(children); c++)
		{
			var _child = children[c];
			var _result = _child.run();
			
			if _result == BTstatus.FAILURE
			{
				return BTstatus.FAILURE;
			}
			
		}
		
		return BTstatus.SUCCESS;
		
	}
}

function parallelNodeBT(_name, _children, _successPolicy) : compositeNodeBT(_name, _children) constructor
{
    // _successPolicy could be "ALL" or "ANY"
	successPolicy = _successPolicy;
	
    nodeType = NodeType.parallel;
	
    run = function()
    {
        var successCount = 0;
        var failureCount = 0;
        
        for (var c = 0; c < array_length(children); c++)
        {
            var _child = children[c];
            var _result = _child.run();
            
            if (_result == BTstatus.SUCCESS)
            {
                successCount += 1;
            }
            else
            {
                failureCount += 1;
            }
        }
        
        if (successPolicy == "ALL")
        {
            if (failureCount == 0)
            {
                return BTstatus.SUCCESS;
            }
            else
            {
                return BTstatus.FAILURE;
            }
        }
        else if (successPolicy == "ANY")
        {
            if (successCount > 0)
            {
                return BTstatus.SUCCESS;
            }
            else
            {
                return BTstatus.FAILURE;
            }
        }
        
        // Fallback (should not happen)
        return BTstatus.FAILURE;
    }
}

#endregion


