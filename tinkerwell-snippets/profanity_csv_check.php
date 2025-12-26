<?php
use App\Services\Reviews\ReviewContentFilter;
use Illuminate\Pipeline\Pipeline;
use App\Services\Reviews\Clean\ProfanityFilter;
use App\Services\Reviews\Clean\RemovePersonalInformation;
use App\Services\Reviews\Clean\RemoveTags;
use App\Models\Organization;
use App\Models\OrgSettings;
use App\Cache\Reviews\ReviewsSettingsCacheService;

$organization = Organization::find(1);

$generalSettings = app(ReviewsSettingsCacheService::class)
            ->getReviewSettingsFromCache(
                $organization->uuid,
                  OrgSettings::GENERAL_SETTINGS
 );

$reviewText = "test-bad-word benitto raj test bad_word1 bad_wodr2 brendonbeni42@gmail.com";

$data = [
            'content' => $reviewText,
            'integration' => $organization->integration,
            'organization' => $organization,
            'reviewGeneralSettings' => $generalSettings,
];

$data =  app(Pipeline::class)
            ->send($data)
            ->through([
                ProfanityFilter::class,
                RemoveTags::class,
                RemovePersonalInformation::class,
            ])
            ->thenReturn();

return $data['content'];
