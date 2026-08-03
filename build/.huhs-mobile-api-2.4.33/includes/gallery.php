<?php

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Kinyeri a Final Tiles Gallery ID-ját a bejegyzésből.
 */
function huhs_get_gallery_id($content)
{
    if (preg_match('/\[FinalTilesGallery\s+id=[\'"]?(\d+)[\'"]?\]/i', $content, $matches)) {
        return (int)$matches[1];
    }

    return 0;
}

/**
 * Lekéri a galéria képeit az adatbázisból.
 */
function huhs_get_gallery_images($content)
{
    global $wpdb;

    $galleryId = huhs_get_gallery_id($content);

    if (!$galleryId) {
        return array();
    }

    $table = $wpdb->prefix . 'FinalTiles_gallery_images';

    $rows = $wpdb->get_results(
        $wpdb->prepare(
            "
            SELECT
                imageId,
                imagePath,
                title,
                alt,
                description,
                sortOrder
            FROM {$table}
            WHERE gid = %d
            ORDER BY sortOrder ASC
            ",
            $galleryId
        )
    );

    if (empty($rows)) {
        return array();
    }

    $images = array();

    foreach ($rows as $row) {

        $images[] = array(
            'id'          => (int)$row->imageId,
            'url'         => $row->imagePath,
            'title'       => $row->title ?? '',
            'alt'         => $row->alt ?? '',
            'description' => $row->description ?? '',
            'order'       => (int)$row->sortOrder,
        );
    }

    return $images;
}