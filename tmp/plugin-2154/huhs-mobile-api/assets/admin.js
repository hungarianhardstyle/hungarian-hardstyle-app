jQuery(function ($) {

    $('.huhs-image-upload').on('click', function (e) {

        e.preventDefault();

        const button = $(this);
        const target = button.data('target');

        const frame = wp.media({
            title: 'Kép kiválasztása',
            button: {
                text: 'Használom ezt a képet'
            },
            multiple: false
        });

        frame.on('select', function () {

            const attachment = frame.state().get('selection').first().toJSON();

            $('#' + target).val(
                button.data('value') === 'url' ? attachment.url : attachment.id
            );

            $('#' + target + '_preview')
                .attr('src', attachment.url);

        });

        frame.open();

    });

});
