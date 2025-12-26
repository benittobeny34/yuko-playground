<?php
use App\WorkFlows\WorkflowTraverser;
use App\Models\WorkFlows\WorkFlow;

$workflow = WorkFlow::find(1);
$triggerNode = $workflow->trigger_node;

$traverser = new WorkflowTraverser($triggerNode);

$yesPathCheck = false;

while($traverser->hasMoreNodes()) {
  $nodeType =  optional($traverser->getCurrentNode())->getNodeType();
  echo $nodeType . "\n";

  if($nodeType == 'binaryDecisionNode') {
    $traverser->getBinaryNextNode($yesPathCheck);
  } else {
    $traverser->next();
  }
}



