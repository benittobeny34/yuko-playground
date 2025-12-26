<?php
use Workflow\ConditionCheck\ConditionProcessor;
use Workflow\DataPreparation\EventDataProvider;
use App\Models\WorkFlows\Node;
use App\Models\Event;
use App\Models\Review;

$node = Node::findByUuid("397308a5-1b3d-4fdf-8c17-b74075a02ead");

$event = Event::findByUuid("42e084e0-e65d-4964-8bc5-82073942ae38");

$triggerNodeCast = $node->data;
$preparedData = app(EventDataProvider::class)->getTriggerEventData(
  $event,
  $triggerNodeCast->getTriggerFilters($triggerNodeCast->trigger_filters)
);

$isConditionPassed = app(ConditionProcessor::class)->checkTriggerNodeConditions(
  $node,
  $event,
  $preparedData,
  [
    "flow_uuid" => $node->workflow_uuid
  ]
);
