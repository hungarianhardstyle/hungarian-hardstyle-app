<?php

if (!defined('ABSPATH')) {
    exit;
}

get_header();
?>
<main class="huhs-public-archive">
    <style>
        .huhs-public-archive{background:#0e0e0e;box-sizing:border-box;min-height:70vh;padding:42px 20px 70px;width:100%}
    </style>
    <?php echo do_shortcode('[huhs_events title="Események"]'); ?>
</main>
<?php
get_footer();
