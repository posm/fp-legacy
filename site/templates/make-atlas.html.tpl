<!DOCTYPE html>
<html>
<head>
    <title>Make - fieldpapers.org</title>
    <link rel="stylesheet" href="{$base_dir}/css/fieldpapers.css" type="text/css" />
    <script type="text/javascript" src="{$base_dir}/modestmaps.js"></script>
    <script type="text/javascript" src="{$base_dir}/raphael.js"></script>
    
    <script type="text/javascript">
        {literal}
        
        var map = null,
            map_layer;
        
        var paper_orientations = {'landscape': 1.50, 'portrait': .75},
            page_aspect_ratio = paper_orientations['landscape'],
            atlas_aspect_ratio;
        
        var rect = null,
            canvas = null,
            lines = null;
        
        var num_rows,
            num_columns;
        
        var scaleControl,
            dragControl,
            dragControlCoordinates,
            scaleControlCoordinates;
        
        var canvas_fill;
        
        var horizontal_add,
            vertical_add,
            horizontal_remove,
            vertical_remove,
            page_dimensions;
        
        var page_button_width = 33,
            page_button_height = 46,
            remove_column_button_width = 23,
            remove_column_button_height = 26,
            remove_row_button_width = 26,
            remove_row_button_height = 22;
            
        function setProvider(provider)
        {        
            if (provider === "Satellite + Labels")
            {
                var tileURL = 'http://tile.stamen.com/boner/{Z}/{X}/{Y}.jpg';
            } else if (provider === "Satellite Only") {
                var tileURL = 'http://tile.stamen.com/bing-lite/{Z}/{X}/{Y}.jpg';
            } else if (provider === "Black & White") {
                var tileURL = 'http://tile.stamen.com/toner-lite/{Z}/{X}/{Y}.png';
            } else if (provider === "Street Map") {
                var tileURL = 'http://tile.openstreetmap.org/{Z}/{X}/{Y}.png';
            }
            
            document.getElementById('provider').value = tileURL;
            
            map_layer.setProvider(new MM.TemplatedMapProvider(tileURL));
        }
        
        function setMapHeight()
        {   
            var map_height = window.innerHeight - document.getElementById('nav').offsetHeight;
            
            document.getElementById('map').style.height = map_height + 'px';
            
            // Reset Canvas
            if (canvas)
            {                
                canvas.setSize(window.innerWidth, map_height);
                
                changeCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
            }
        }
        
        function checkAtlasOverflow(topLeftPoint, bottomRightPoint, resize)
        {   
            var map_extent = map.getExtent();
            var map_top_left_point = map.locationPoint(map_extent[0]);
            var map_bottom_right_point = map.locationPoint(map_extent[1]);
                            
            if (topLeftPoint.x < map_top_left_point.x || topLeftPoint.y < map_top_left_point.y ||
                bottomRightPoint.x > map_bottom_right_point.x || bottomRightPoint.y > map_bottom_right_point.y)
            { 
                if (resize === true)
                {                        
                    var center_point = map.locationPoint(map.getCenter());
                    
                    dragControlCoordinates.x = center_point.x - .5 * page_dimensions.width;
                    dragControlCoordinates.y = center_point.y - .5 * page_dimensions.height;

                    scaleControlCoordinates = {x: dragControlCoordinates.x + page_dimensions.width,
                                               y: dragControlCoordinates.y + page_dimensions.height};
                    
                    changeCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
                    
                    resetAtlas();
                } else {
                    var dragControlLocation = map.pointLocation(dragControlCoordinates);
                    var scaleControlLocation = map.pointLocation(scaleControlCoordinates);
                    
                    map.setCenterZoom(map.getCenter(),map.getZoom()-1);
                    
                    dragControlCoordinates = map.locationPoint(dragControlLocation);
                    scaleControlCoordinates = map.locationPoint(scaleControlLocation);
                    
                    changeCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
                    
                    resetAtlas();
                }
            }
        }
        
        function resetAtlas()
        {
            setAtlasBounds(dragControlCoordinates.x, dragControlCoordinates.y,scaleControlCoordinates.x,scaleControlCoordinates.y);
            
            dragControl.attr({
                    x: dragControlCoordinates.x,
                    y: dragControlCoordinates.y
            });
            
            scaleControl.attr({
                    x: scaleControlCoordinates.x,
                    y: scaleControlCoordinates.y
            });
            
            
            rect.attr({
                x: dragControlCoordinates.x,
                y: dragControlCoordinates.y,
                width: scaleControlCoordinates.x - dragControlCoordinates.x,
                height: scaleControlCoordinates.y - dragControlCoordinates.y
            });
            
            resetAtlasAttributes();
        }
        
        function changeOrientation(orientation) {
            if (document.getElementById('orientation').value === orientation)
            {
                return;
            }
            
            changeOrientationButtonStyle(orientation);
            
            document.getElementById('orientation').value = orientation;
            
            if (page_aspect_ratio > 1)
            {
                var new_page_height = (scaleControlCoordinates.x - dragControlCoordinates.x)/num_columns;
                page_aspect_ratio = paper_orientations[orientation];
                
                var new_page_width = page_aspect_ratio * new_page_height;
            } else {
                var new_page_width = (scaleControlCoordinates.y - dragControlCoordinates.y)/num_rows;
                page_aspect_ratio = paper_orientations[orientation];
                
                var new_page_height = new_page_width/page_aspect_ratio; 
            }
            
            atlas_aspect_ratio = (num_columns/num_rows) * page_aspect_ratio;
            
            scaleControlCoordinates.x = dragControlCoordinates.x + num_columns * new_page_width;
            scaleControlCoordinates.y = dragControlCoordinates.y + num_rows * new_page_height;
                        
            scaleControl.attr({
                    x: scaleControlCoordinates.x,
                    y: scaleControlCoordinates.y
            });
            
            changeCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
            
            resetAtlasAttributes();
                        
            rect.remove();
            setAtlasBounds(dragControlCoordinates.x, dragControlCoordinates.y, scaleControlCoordinates.x, scaleControlCoordinates.y);
            drawAtlas();
            
            checkAtlasOverflow(dragControlCoordinates, scaleControlCoordinates);
        }
        
        function changeOrientationButtonStyle(orientation)
        {
            /* probably not necessary */
            if (document.getElementById('orientation').value === orientation)
            {
                return;
            }
            
            if (orientation === 'portrait')
            {
                document.getElementById('portrait_button').setAttribute("class", "radio_portrait_selected");
                document.getElementById('landscape_button').setAttribute("class", "radio_landscape");
            } else if (orientation === 'landscape') {
                document.getElementById('portrait_button').setAttribute("class", "radio_portrait");
                document.getElementById('landscape_button').setAttribute("class", "radio_landscape_selected");
            }
        }
        
        function resetAtlasAttributes()
        {
            if (num_rows > 1 && num_columns > 1)
            {
                horizontal_remove.show();
                vertical_remove.show();   
            } else if (num_columns > 1 && num_rows === 1) {
                horizontal_remove.show();  
                vertical_remove.hide(); 
            } else if (num_rows > 1 && num_columns === 1) {
                horizontal_remove.hide();
                vertical_remove.show();
            } else {
                horizontal_remove.hide();
                vertical_remove.hide(); 
            }
            
            var pathString = drawPages(dragControlCoordinates, scaleControlCoordinates,num_rows,num_columns);
            
            lines.attr({
                path: pathString
            });
                            
            horizontal_add.attr({
                x: scaleControlCoordinates.x - .5 * page_button_width,
                y: dragControlCoordinates.y + .5 * (scaleControlCoordinates.y - dragControlCoordinates.y) - .5 * page_button_height
            });
            
            horizontal_remove.attr({
                x: scaleControlCoordinates.x - .5 * page_button_width - remove_column_button_width,
                y: dragControlCoordinates.y + .5 * (scaleControlCoordinates.y - dragControlCoordinates.y) - .5 * remove_column_button_height
            });
            
            vertical_add.attr({
                x: dragControlCoordinates.x + .5 * (scaleControlCoordinates.x - dragControlCoordinates.x) - .5 * page_button_width,
                y: scaleControlCoordinates.y - .5 * page_button_height
            });
            
            vertical_remove.attr({
                x: dragControlCoordinates.x + .5 * (scaleControlCoordinates.x - dragControlCoordinates.x) - .5 * remove_row_button_width - 1,
                y: scaleControlCoordinates.y - .5 * page_button_height - remove_row_button_height
            });
        }
        
        function setAtlasBounds(drag_position_x, drag_position_y, scale_position_x, scale_position_y)
        {
            page_dimensions.x = drag_position_x;
            page_dimensions.y = drag_position_y;
            
            page_dimensions.width = scale_position_x - drag_position_x;
            page_dimensions.height = scale_position_y - drag_position_y;
        }
        
        function drawPages(dragControlCoordinates, scaleControlCoordinates,num_rows,num_columns)
        {
            var width = scaleControlCoordinates.x - dragControlCoordinates.x;
            var increment = width/num_columns;
            
            var pathString = '';
            for (var i = 0; i < num_columns - 1; i++) {
                // Creating string
                var verticalLineX = dragControlCoordinates.x + (i+1) * increment;
                
                pathString = pathString + 'M' + verticalLineX + ',' + dragControlCoordinates.y +
                             'L' + verticalLineX + ',' + scaleControlCoordinates.y;
            }
            
            var height = scaleControlCoordinates.y - dragControlCoordinates.y;
            increment = height/num_rows;
            
            for (var i = 0; i < num_rows - 1; i++) {
                var horizontalLineY = dragControlCoordinates.y + (i+1) * increment;
                
                pathString = pathString + 'M' + dragControlCoordinates.x + ',' + horizontalLineY +
                            'L' + scaleControlCoordinates.x + ',' + horizontalLineY;
            }
            
            return pathString;
        }
        
        function drawAtlas() {
            rect = canvas.rect(dragControlCoordinates.x, 
                               dragControlCoordinates.y,
                               scaleControlCoordinates.x - dragControlCoordinates.x,
                               scaleControlCoordinates.y - dragControlCoordinates.y);
            
            rect.attr("stroke", "#050505");
            rect.insertBefore(scaleControl);
            rect.insertBefore(dragControl);
            rect.insertBefore(horizontal_add);
        }
        
        function createCanvasFillPath(topLeftPoint, bottomRightPoint)
        {   
            // ** Note: fill-rule attribute is not currently supported by Raphael.
            // By default, the fill-rule is nonzero. To achieve the correct fill,
            // we draw the outer path counter-clockwise to the clockwise inner path.
            
            var pathString = 'M0,0L0,' + canvas.height + 'L' + canvas.width + ',' + canvas.height + 'L' +
                             canvas.width + ',0L0,0M' + topLeftPoint.x + ',' + topLeftPoint.y + 'L' +
                             bottomRightPoint.x + ',' + topLeftPoint.y +
                             'L' + bottomRightPoint.x + ',' + bottomRightPoint.y + 'L' +
                             topLeftPoint.x + ',' + bottomRightPoint.y + 'L' + topLeftPoint.x +
                             topLeftPoint.y + 'Z';
            
            return pathString;
        }
        
        
        function changeCanvasFillPath(topLeftPoint, bottomRightPoint)
        {
            var pathString = createCanvasFillPath(topLeftPoint, bottomRightPoint)
            canvas_fill.attr({
                path: pathString
            });
        }
        
        function setAndSubmitData()
        {
            updatePageExtents(dragControlCoordinates, scaleControlCoordinates);
            
            document.forms['compose_print'].submit();
            //return true;
        }
        
        function updatePageExtents(topLeftPoint, bottomRightPoint)
        {   
            console.log('update');
            var width_increment = (bottomRightPoint.x - topLeftPoint.x)/num_columns;
            var height_increment = (bottomRightPoint.y -topLeftPoint.y)/num_rows;
            
            var pages = [];
            for (var i = 0; i < num_rows; i++) {
                for (var j = 0; j < num_columns; j++) {
                    var topLeftLocation = map.pointLocation(new MM.Point(topLeftPoint.x + j*width_increment, topLeftPoint.y + i*height_increment));
                    var bottomRightLocation = map.pointLocation(new MM.Point(topLeftPoint.x + (j+1)*width_increment, topLeftPoint.y + (i+1)*height_increment));
                    var page = [topLeftLocation.lat, topLeftLocation.lon, bottomRightLocation.lat, bottomRightLocation.lon];
                    pages.push(page.join(','));
                }
            }
            
            updateAtlasFormFields(pages);
        }
                
        function updateAtlasFormFields(pages)
        {   
            // TODO: Empty fields
            for (var i = 0; i < pages.length; i++)
            {
                var page_extent = document.createElement('input');
                page_extent.name = "pages[" + i + "]";
                page_extent.type = 'hidden';
                page_extent.value = pages[i];
                document.getElementById('compose_print').appendChild(page_extent);
            }
        }
        
        function initUI () {
            ////
            // Map
            ////
            var MM = com.modestmaps;
            
            var satellite_labels_provider = new MM.TemplatedMapProvider('http://tile.stamen.com/boner/{Z}/{X}/{Y}.jpg');
            map_layer = new MM.Layer(satellite_labels_provider);
            
            setMapHeight();
            
            map = new MM.Map('map', map_layer,null,[new MM.DragHandler(), new MM.DoubleClickHandler()]);
                                
            map.setCenterZoom(new MM.Location({/literal}{$center}{literal}), 10); // Set a default case
            
            // Initialize value of page_zoom input
            
            document.getElementById('zoom-out').style.display = 'inline';
            document.getElementById('zoom-in').style.display = 'inline';
            
            document.getElementById('page_zoom').value = 12;
            document.getElementById('provider').value = 'http://tile.stamen.com/boner/{Z}/{X}/{Y}.jpg';
            
            ////
            // UI
            ////
            
            // Atlas Information            
            num_rows = 1;
            num_columns = 1;
            
            //Initialize
            atlas_aspect_ratio = page_aspect_ratio*(num_columns/num_rows);
            //document.getElementById('radio_landscape').checked = true; // Initially landscape
            
            document.getElementById('paper_size').value = 'letter';
            document.getElementById('orientation').value = 'landscape';
                        
            function updateDragControlCoordinates(dx, dy)
            {
                // Make this more general
                dragControlCoordinates.x = dragControlCoordinates.x + dx;
                dragControlCoordinates.y = dragControlCoordinates.y + dy;
            }
            
            function updateScaleControlCoordinates(dx, dy)
            {
                // Make this more general
                scaleControlCoordinates.x = scaleControlCoordinates.x + dx;
                scaleControlCoordinates.y = scaleControlCoordinates.y + dy;
            }
                                      
            /////
            /// Set up the display objects
            /////
            
            canvas = Raphael("canvas");
                                    
            var ne_location = new MM.Location({/literal}{$extent.ne}{literal});
            var sw_location = new MM.Location({/literal}{$extent.sw}{literal});
            
            var nw_point = map.locationPoint(new MM.Location(ne_location.lat,sw_location.lon));
            var se_point = map.locationPoint(new MM.Location(sw_location.lat,ne_location.lon));
            
            var center_point = map.locationPoint(new MM.Location({/literal}{$center}{literal}));
            console.log('center_point', center_point);
            
            var page_height = 200,
                canvasOriginX = (center_point.x - .5 * page_height * atlas_aspect_ratio) || 160,
                canvasOriginY = (center_point.y - .5 * page_height) || 160,
                controlRadius = 15;
            
            page_dimensions = {x: canvasOriginX, y: canvasOriginY, width: page_height*atlas_aspect_ratio, height: page_height};
                            
            // Initialize Coordinate Objects
            scaleControlCoordinates = {x: page_height*atlas_aspect_ratio + canvasOriginX, y: page_height + canvasOriginY};
            dragControlCoordinates = {x: canvasOriginX, y: canvasOriginY};
                        
            horizontal_add = canvas.image("{/literal}{$base_dir}{literal}/img/button-add-off.png",
                            canvasOriginX+page_height*atlas_aspect_ratio-.5*page_button_width,
                            canvasOriginY + .5 * page_height - .5 * page_button_height,
                            33,
                            46);
            horizontal_add.attr("cursor","pointer");
                        
            horizontal_remove = canvas.image("{/literal}{$base_dir}{literal}/img/button-remove-column-off.png",
                                             canvasOriginX + page_height*atlas_aspect_ratio - remove_column_button_width - .5 * page_button_width,
                                             canvasOriginY + .5 * page_height - .5 * remove_column_button_height,
                                             remove_column_button_width,
                                             remove_column_button_height);
            horizontal_remove.attr("cursor","pointer");
            horizontal_remove.hide();
                        
            vertical_add = canvas.image("{/literal}{$base_dir}{literal}/img/button-add-off.png",
                                         canvasOriginX + .5 * page_height * atlas_aspect_ratio - .5 * page_button_width,
                                         canvasOriginY + page_height - .5 * page_button_height,
                                         page_button_width,
                                         page_button_height);
            vertical_add.attr("cursor","pointer");
                        
            vertical_remove = canvas.image("{/literal}{$base_dir}{literal}/img/button-remove-row-off.png",
                                              canvasOriginX + .5 * page_height * atlas_aspect_ratio - .5 * remove_row_button_width - 1,
                                              canvasOriginY + page_height - .5 * page_button_height - remove_row_button_height,
                                              remove_row_button_width,
                                              remove_row_button_height);
            vertical_remove.attr("cursor","pointer");
            vertical_remove.hide();
            
            dragControl = canvas.image("{/literal}{$base_dir}{literal}/img/button-move-atlas-off.png",
                                        dragControlCoordinates.x,
                                        dragControlCoordinates.y,
                                        46,
                                        46);
            dragControl.attr("cursor","move");
            dragControl.translate(-3, -3);
            
            scaleControl = canvas.image("{/literal}{$base_dir}{literal}/img/button-scale-atlas-off.png",
                scaleControlCoordinates.x,
                scaleControlCoordinates.y,
                46,
                46);
            scaleControl.attr("cursor","se-resize");
            scaleControl.translate(-23, -23);
            
            drawAtlas(scaleControl,dragControl,horizontal_add);
            
            // Filling the canvas outside
            var fill_path = createCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
            canvas_fill = canvas.path(fill_path);
            canvas_fill.attr("fill", "#050505");
            canvas_fill.attr("opacity", .3);
            canvas_fill.insertBefore(rect);
            
            var pathString = drawPages(dragControlCoordinates, scaleControlCoordinates,num_rows,num_columns);
            
            lines = canvas.path(pathString);
            lines.attr("stroke", "#050505");
            lines.insertBefore(rect);
            
            /////
            // Handle the highlighting of all of the atlas controls
            /////
            
            /* The next two variables are being used in the scale control drag handler */
            var changeHighlightImages = true;
            var mouseInsideScaleControl = false;
                        
            function setControlHighlight()
            {
                dragControl.mouseover(function(e) {
                    e.stopPropagation();
                    this.attr("src", "{/literal}{$base_dir}{literal}/img/button-move-atlas-on.png");     
                });
                
                dragControl.mouseout(function(e) {
                    e.stopPropagation();
                    this.attr("src", "{/literal}{$base_dir}{literal}/img/button-move-atlas-off.png");
                });
            
                scaleControl.mouseover(function(e) {
                    e.stopPropagation();
                    
                    mouseInsideScaleControl = true;
                    
                    if (changeHighlightImages) {
                        scaleControl.attr("src", "{/literal}{$base_dir}{literal}/img/button-scale-atlas-on.png");
                    }
                });
                
                scaleControl.mouseout(function(e) {
                    e.stopPropagation();
                    
                    mouseInsideScaleControl = false;
                    
                    if (changeHighlightImages) {
                        scaleControl.attr("src", "{/literal}{$base_dir}{literal}/img/button-scale-atlas-off.png");
                    }
                });
                                
                horizontal_remove.mouseover(function(e) {
                    e.stopPropagation();
                    this.attr("src", "{/literal}{$base_dir}{literal}/img/button-remove-column-on.png");
                });
                
                horizontal_remove.mouseout(function(e) {
                    e.stopPropagation();
                    this.attr("src", "{/literal}{$base_dir}{literal}/img/button-remove-column-off.png");
                });
                
                horizontal_add.mouseover(function (e) {
                    e.stopPropagation();
                    this.attr("src", "{/literal}{$base_dir}{literal}/img/button-add-on.png");
                });

                horizontal_add.mouseout(function (e) {
                    e.stopPropagation();
                    this.attr("src", "{/literal}{$base_dir}{literal}/img/button-add-off.png");
                });
                
                vertical_add.mouseover(function(e) {
                    e.stopPropagation();
                    this.attr("src", "{/literal}{$base_dir}{literal}/img/button-add-on.png");
                });
                
                vertical_add.mouseout(function(e) {
                    e.stopPropagation();
                    this.attr("src", "{/literal}{$base_dir}{literal}/img/button-add-off.png");
                });
                
                vertical_remove.mouseover(function(e) {
                    e.stopPropagation();
                    this.attr("src", "{/literal}{$base_dir}{literal}/img/button-remove-row-on.png");
                });
                
                vertical_remove.mouseout(function(e) {
                    e.stopPropagation();
                    this.attr("src", "{/literal}{$base_dir}{literal}/img/button-remove-row-off.png");
                });
            }
            
            setControlHighlight();
            
            /////
            // Drag Control drag handler: move, start, end
            /////
            var initialX, initialY; // These are used by the dragControl handler and the scaleControl handler
                        
            var delta = {dx: 0, dy: 0};
            
            dragControl.drag(
            
                function (dx,dy,x,y,e) {
                    e.stopPropagation();
                    
                    //this.attr("src", "{/literal}{$base_dir}{literal}/img/button-move-atlas-on.png"); // Needed?
                    
                    dragControlCoordinates.x = initialX + dx;
                    dragControlCoordinates.y = initialY + dy;
                    
                    scaleControlCoordinates.x = dragControlCoordinates.x + page_dimensions.width;
                    scaleControlCoordinates.y = dragControlCoordinates.y + page_dimensions.height;
                    
                    changeCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
                    
                    setAtlasBounds(dragControlCoordinates.x, dragControlCoordinates.y,scaleControlCoordinates.x,scaleControlCoordinates.y);
                    
                    dragControl.attr({
                            x: dragControlCoordinates.x,
                            y: dragControlCoordinates.y
                    });
                    
                    scaleControl.attr({
                            x: scaleControlCoordinates.x,
                            y: scaleControlCoordinates.y
                    });
                    
                    rect.attr({
                        x: dragControlCoordinates.x,
                        y: dragControlCoordinates.y
                    });
                    
                    resetAtlasAttributes();
                },
            
                function(x,y,e) {                                
                    e.stopPropagation();
                    
                    this.attr("cursor", "grabbing");
                    this.attr("cursor", "-moz-grabbing");
                    this.attr("cursor", "-webkit-grabbing");
                    
                    document.getElementById('canvas').style.cursor = "grabbing";
                    document.getElementById('canvas').style.cursor = "-moz-grabbing";
                    document.getElementById('canvas').style.cursor = "-webkit-grabbing";
                    
                    initialX = dragControl.attr("x");
                    initialY = dragControl.attr("y");
                },
            
                function () {
                    this.attr("cursor", "move");
                    
                    document.getElementById('canvas').style.cursor = "default";                                               
                    checkAtlasOverflow(dragControlCoordinates, scaleControlCoordinates);
                    //updatePageExtents(dragControlCoordinates, scaleControlCoordinates);
                }
            );
            
            /////
            // scaleControl drag handler: move, start, end
            /////
                                    
            scaleControl.drag(
            
                function(dx, dy, mouseX, mouseY, e) {
                    //e.stoppropagation?
                    
                    var curX = initialX + dx;
                    var curY = initialY + dy;
                    
                    var mouse_width_dx = curX - page_dimensions.x;
                    var mouse_height_dy = curY - page_dimensions.y;
                    
                    if (mouse_width_dx <= 0 || mouse_height_dy <= 0) 
                    {
                        return;
                    }
                    
                    var new_width,
                        new_height;
                        
                    if ((mouse_width_dx/mouse_height_dy) >= atlas_aspect_ratio)
                    {
                        // Change X to track mouse
                        new_width = mouse_width_dx;
                        new_height = mouse_width_dx/atlas_aspect_ratio;
                    } else {
                        // Change Y to track mouse
                        new_width = mouse_height_dy * atlas_aspect_ratio;
                        new_height = mouse_height_dy;
                    }
                    
                    this.attr({
                        x: page_dimensions.x + new_width,
                        y: page_dimensions.y + new_height
                    });
                    
                    page_dimensions.width = new_width;
                    page_dimensions.height = new_height;
                    
                    scaleControlCoordinates.x = page_dimensions.x + page_dimensions.width;
                    scaleControlCoordinates.y = page_dimensions.y + page_dimensions.height;
                    
                    changeCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
                    
                    setAtlasBounds(dragControlCoordinates.x, dragControlCoordinates.y,scaleControlCoordinates.x, scaleControlCoordinates.y);     
                                                           
                    rect.remove();
                    drawAtlas(scaleControl,dragControl,horizontal_add);
                    
                    resetAtlasAttributes();
                },
                
                function(mouseX,mouseY,e) {
                    e.stopPropagation();
                    
                    changeHighlightImages = false;
                    
                    this.attr("cursor", "grabbing");
                    this.attr("cursor", "-moz-grabbing");
                    this.attr("cursor", "-webkit-grabbing");
                    
                    document.getElementById('canvas').style.cursor = "grabbing";
                    document.getElementById('canvas').style.cursor = "-moz-grabbing";
                    document.getElementById('canvas').style.cursor = "-webkit-grabbing";
                                    
                    initialX = scaleControlCoordinates.x;
                    initialY = scaleControlCoordinates.y;
                },
                
                function(e) {
                    //turnOnControlHighlight();
                    changeHighlightImages = true;
                    if (!mouseInsideScaleControl) {
                        scaleControl.attr("src", "{/literal}{$base_dir}{literal}/img/button-scale-atlas-off.png");
                    }
                    
                    //scaleControlCoordinates.x = this.attr("x");
                    //scaleControlCoordinates.y = this.attr("y");
                    this.attr("cursor", "se-resize");
                    document.getElementById('canvas').style.cursor = "default";
                    
                    checkAtlasOverflow(dragControlCoordinates, scaleControlCoordinates);
                }
            );

            var addHorizontalPage = function() {
                num_columns++;
                
                if (num_rows * num_columns > 1)
                {
                    document.getElementById("page_count").innerHTML = '<b>' + num_rows * num_columns + '</b>';
                    document.getElementById("page_plural").innerHTML = 'PAGES';
                } else {
                    document.getElementById("page_count").innerHTML = '<b>' + num_rows * num_columns + '</b>';
                    document.getElementById("page_plural").innerHTML = 'PAGE';
                }
                
                atlas_aspect_ratio = page_aspect_ratio*(num_columns/num_rows);
                
                page_dimensions.width = page_dimensions.width * (num_columns/(num_columns - 1))
                
                scaleControlCoordinates.x = page_dimensions.x + page_dimensions.width;
                scaleControl.attr({
                    x: scaleControlCoordinates.x
                });
                
                changeCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
                
                checkAtlasOverflow(dragControlCoordinates, scaleControlCoordinates);
                                
                rect.attr({
                    // This is really atlas dimensions at this point.
                    width:  page_dimensions.width
                });
                
                resetAtlasAttributes();
                //updatePageExtents(dragControlCoordinates, scaleControlCoordinates);
            }
            
            var removeHorizontalPage = function() {
                if (num_columns === 1)
                {
                    return;
                }
            
                num_columns--;
                
                if (num_rows * num_columns > 1)
                {
                    document.getElementById("page_count").innerHTML = '<b>' + num_rows * num_columns + '</b>';
                    document.getElementById("page_plural").innerHTML = 'PAGES';
                } else {
                    document.getElementById("page_count").innerHTML = '<b>' + num_rows * num_columns + '</b>';
                    document.getElementById("page_plural").innerHTML = 'PAGE';
                }
                
                atlas_aspect_ratio = page_aspect_ratio*(num_columns/num_rows);
                
                page_dimensions.width = page_dimensions.width * (num_columns/(num_columns + 1))
                
                scaleControlCoordinates.x = page_dimensions.x + page_dimensions.width;
                scaleControl.attr({
                    x: scaleControlCoordinates.x
                });
                
                changeCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
                
                //checkAtlasOverflow(dragControlCoordinates, scaleControlCoordinates); Needed?
                                
                rect.attr({
                    width:  page_dimensions.width
                });
                
                resetAtlasAttributes();
                //updatePageExtents(dragControlCoordinates, scaleControlCoordinates);
            }
            
            var addVerticalPage = function() {
                num_rows++;
                
                if (num_rows * num_columns > 1)
                {
                    document.getElementById("page_count").innerHTML = '<b>' + num_rows * num_columns + '</b>';
                    document.getElementById("page_plural").innerHTML = 'PAGES';
                } else {
                    document.getElementById("page_count").innerHTML = '<b>' + num_rows * num_columns + '</b>';
                    document.getElementById("page_plural").innerHTML = 'PAGE';
                }
                
                atlas_aspect_ratio = page_aspect_ratio*(num_columns/num_rows);
                
                page_dimensions.height = page_dimensions.height * (num_rows/(num_rows - 1))
                
                scaleControlCoordinates.y = page_dimensions.y + page_dimensions.height;
                scaleControl.attr({
                    y: scaleControlCoordinates.y
                });
                
                changeCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
                
                checkAtlasOverflow(dragControlCoordinates, scaleControlCoordinates);
                                
                rect.attr({
                    height:  page_dimensions.height
                });
                
                resetAtlasAttributes();
                //updatePageExtents(dragControlCoordinates, scaleControlCoordinates);
            }
            
            var removeVerticalPage = function() {
                if (num_rows === 1)
                {
                    return;
                }
                
                num_rows--;
                
                if (num_rows * num_columns > 1)
                {
                    document.getElementById("page_count").innerHTML = '<b>' + num_rows * num_columns + '</b>';
                    document.getElementById("page_plural").innerHTML = 'PAGES';
                } else {
                    document.getElementById("page_count").innerHTML = '<b>' + num_rows * num_columns + '</b>';
                    document.getElementById("page_plural").innerHTML = 'PAGE';
                }
                
                atlas_aspect_ratio = page_aspect_ratio*(num_columns/num_rows);
                
                page_dimensions.height = page_dimensions.height * (num_rows/(num_rows + 1))
                
                
                scaleControlCoordinates.y = page_dimensions.y + page_dimensions.height;
                scaleControl.attr({
                    y: scaleControlCoordinates.y
                });
                
                changeCanvasFillPath(dragControlCoordinates, scaleControlCoordinates);
                
                //checkAtlasOverflow(dragControlCoordinates, scaleControlCoordinates); // Needed?
                                
                rect.attr({
                    height:  page_dimensions.height
                });
                
                resetAtlasAttributes();
                //updatePageExtents(dragControlCoordinates, scaleControlCoordinates);
            }
            
            ////
            //  Set Click Handlers for row and columm buttons
            ////            
            horizontal_add.click(function (e) {
                e.stopPropagation();
                addHorizontalPage();
                this.attr("src", "{/literal}{$base_dir}{literal}/img/button-add-off.png");
            });
            
            horizontal_remove.click(function(e) {
                e.stopPropagation()
                removeHorizontalPage();
                this.attr("src", "{/literal}{$base_dir}{literal}/img/button-remove-column-off.png");
            });
            
            vertical_add.click(function(e) {
                e.stopPropagation();
                addVerticalPage();
                this.attr("src", "{/literal}{$base_dir}{literal}/img/button-add-off.png");
            });
            
            vertical_remove.click(function(e) {
                e.stopPropagation();
                removeVerticalPage();
                this.attr("src", "{/literal}{$base_dir}{literal}/img/button-remove-row-off.png"); //--> going to removeVerticalPage()
            });
            
            // Map Callbacks
            map.addCallback('zoomed', function(m) {
                document.getElementById('page_zoom').value = map.getZoom();
            });
            
            map.addCallback('resized', function(m) {
                checkAtlasOverflow(dragControlCoordinates, scaleControlCoordinates,true);
            });
                        
            var zoom_in = document.getElementById("zoom-in");
            var zoom_out = document.getElementById("zoom-out");
                        
            var zoom_in_button = document.getElementById('zoom-in-button');
            zoom_in.onmouseover = function() { zoom_in_button.src = "{/literal}{$base_dir}{literal}/img/button-zoom-in-on.png"; };
            zoom_in.onmouseout = function() { zoom_in_button.src = "{/literal}{$base_dir}{literal}/img/button-zoom-in-off.png"; };
            
            zoom_in.onclick = function() { map.zoomIn(); return false; };
            
            var zoom_out_button = document.getElementById('zoom-out-button');
            zoom_out.onmouseover = function() { zoom_out_button.src = "{/literal}{$base_dir}{literal}/img/button-zoom-out-on.png"; };
            zoom_out.onmouseout = function() { zoom_out_button.src = "{/literal}{$base_dir}{literal}/img/button-zoom-out-off.png"; };
            
            zoom_out.onclick = function() { map.zoomOut(); return false; };
            
            // Window Callbacks
            window.onresize = setMapHeight;
        }
        {/literal}
    </script>
    <style type="text/css">
        {literal}
        h1 {
           margin-left: 20px;
        }
        
        body {
           background: #fff;
           color: #000;
           font-family: Helvetica, sans-serif;
           margin: 0;
           padding: 0px;
           border: 0;
        }
        #map {
           width: 100%;
           position: relative;
           overflow: hidden;
           z-index: 1;
        }
        
        #canvas {
            width: 100%;
            height: 100%;
            position: absolute;
            z-index: 3;
        }
        
        #zoom-container {
            width: 46px;
            height: 92px;
            position: absolute;
            padding: 8px 0px 0px 20px;
            z-index: 2;
        }
        
        #zoom-in, #zoom-out {
            cursor: pointer;
        }
        
        #atlas_inputs_container {
            height: 0px;
            position: absolute;
            z-index: 2;
            width: 100%;
            top:0;
            text-align: center;
        }
        
        #atlas_inputs {
            padding: 10px 0px 0px 0px;
            margin: -25px auto 0 auto;
            background-color: #FFF;
            border-top: 2px solid #000;
            text-align: center;
            width: 330px;
        }
        
        #page_count_container {
            display: inline-block;
            width: 2em;
            margin: 0px 20px 10px 20px;
            text-align: center;
        }
        
        #page_plural {
            font-size: 0.675em;
            line-height 1.5em;
            color: #666;
        }
        
        #done_button {
            font-size: 13px;
            padding: 0px 8px 0px 8px;
            position: relative;
            top: -8px;
            margin: 0;
        }
        
        .radio_portrait {
            background: url("{/literal}{$base_dir}{literal}/img/button-portrait-off.png") no-repeat;
            display: inline-block;
            padding: 2px 2px 2px 2px;
            margin-left: 5px;
            position: relative;
            top: 3px;
            width: 19px;
            height: 25px;
            cursor: pointer;
        }
        
        .radio_portrait_selected {
            background: url("{/literal}{$base_dir}{literal}/img/button-portrait-selected.png") no-repeat;
            display: inline-block;
            padding: 2px 2px 2px 2px;
            margin-left: 5px;
            position: relative;
            top: 3px;
            width: 19px;
            height: 25px;
            cursor: pointer;
        }
        
        .radio_landscape {
            background: url("{/literal}{$base_dir}{literal}/img/button-landscape-off.png") no-repeat;
            display: inline-block;
            padding: 2px 0px 2px 2px;
            width: 25px;
            height: 19px;
            cursor: pointer;
        }
        
        .radio_landscape_selected {
            background: url("{/literal}{$base_dir}{literal}/img/button-landscape-selected.png") no-repeat;
            display: inline-block;
            padding: 2px 0px 2px 2px;
            width: 25px;
            height: 19px;
            cursor: pointer;
        }
        {/literal}
    </style>
</head>
    <body onload="initUI()">
        {include file="navigation.htmlf.tpl"}
        <div id="container" style="position: relative">
            <div id="atlas_inputs_container">
                <div id="atlas_inputs">
                    <select style="top: -8px; position: relative;" name="provider" onchange="setProvider(this.value);">
                        <option>Satellite + Labels</option>
                        <option>Street Map</option>
                        <option>Satellite Only</option>
                        <option>Black & White</option>
                    </select> 
        
                    <div class="radio_portrait" id="portrait_button" title="Portrait" onclick="changeOrientation('portrait');"></div>            
                    <div class="radio_landscape_selected" id="landscape_button" title="Landscape" onclick="changeOrientation('landscape');"></div>
            
                    <span id="page_count_container">
                        <span class="section" id="page_count"><b>1</b></span><br />
                        <span id="page_plural">PAGE</span>
                    </span>
                    
                    <input id="done_button" type="button" onclick="setAndSubmitData()" value="Done" />
                </div>
            </div>
            <form id="compose_print" method="post" action="{$base_dir}/compose-print.php" style="display:inline; width: 940px; position: absolute;">
                <input type="hidden" name="action" value="compose">
                <input type="hidden" id="page_zoom" name="page_zoom">
                <input type="hidden" id="paper_size" name="paper_size">
                <input type="hidden" id="orientation" name="orientation">
                <input type="hidden" id="provider" name="provider">
                
                <!--
                <select id="forms" name="form_id" style="margin-left: 30px">
                    {if $default_form == 'none'}
                        <option selected>Select a Form for this Atlas</option>
                    {else}
                        <option>Forms</option>
                        <option value="{$default_form.id}" selected>{$default_form.title} ({$default_form.id})</option>
                    {/if}
                    
                    {foreach from=$forms item="form"}
                        {if $form.id != $default_form.id}
                            <option value="{$form.id}">{$form.title} ({$form.id})</option>
                        {/if}
                    {/foreach}
                </select>
                -->
            </form>
            <div id="zoom-container">
                <span id="zoom-in" style="display: none;">
                <img src='{$base_dir}/img/button-zoom-in-off.png' id="zoom-in-button"
                          width="46" height="46" />
                </span>
                <span id="zoom-out" style="display: none;">
                    <img src='{$base_dir}/img/button-zoom-out-off.png' id="zoom-out-button"
                              width="46" height="46" />
                </span>
            </div>
            <div id="map">
                <div id="canvas"></div>
            </div>
        </div>
    </body>
</html>