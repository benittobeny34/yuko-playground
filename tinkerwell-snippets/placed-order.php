<?php
use App\Models\WorkFlows\Node;
use Workflow\DataPreparation\EventDataProvider;
use App\WorkFlows\Events\EventList;
use App\Models\WorkFlows\Workflow;

$node = Node::find(1);

$workflow = Workflow::find(11);

$nodes = $workflow->nodes;

$triggerNode = $nodes->filter(function($node) {
return $node->node_type == 'triggerNode';
})->first();


$provider = app(EventDataProvider::class);

$eventType = EventList::ORDERED_PRODUCT;

$triggerNodeData = $triggerNode->data;

$event_data = [
  'product_id' =>  8,
  'order_id' => 1,
];

return $provider->getTriggerEventData($eventType, $event_data, $triggerNodeData);
