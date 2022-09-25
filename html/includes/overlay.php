<?php

function DisplayOverlay($image_name)
{



?>

    <script src="/js/jquery-loading-overlay/dist/loadingoverlay.min.js"></script>

    <script src="/js/moment/moment-min.js"></script>

    <script src="/js/overlay/oe-overlayeditor.js"></script>
    <script src="/js/overlay/oe-config.js"></script>
    <script src="/js/overlay/oe-uimanager.js"></script>

    <script src="/js/overlay/fields/oe-fieldmanager.js"></script>
    <script src="/js/overlay/fields/oe-field.js"></script>
    <script src="/js/overlay/fields/oe-text.js"></script>
    <script src="/js/overlay/fields/oe-image.js"></script>
    <script src="/js/overlay/oe-exposure.js"></script>

    <script src="/js/bootbox/bootbox.all.js"></script>
    <script src="/js/bootbox/bootbox.locales.min.js"></script>

    <link href="/css/overlay.css" rel="stylesheet">

    <link rel='stylesheet' href='/js/jquery-ui-1.13.1.custom/jquery-ui.min.css' />
    <script src="/js/jquery-ui-1.13.1.custom/jquery-ui.min.js"></script>

    <link rel='stylesheet' href='/js/spectrum/dist/spectrum.css' />
    <script src="/js/spectrum/dist/spectrum.js"></script>

    <link rel='stylesheet' href='/js/jqPropertyGrid/jqPropertyGrid.css' />
    <script src="/js/jqPropertyGrid/jqPropertyGrid.js"></script>

    <link rel="stylesheet" type="text/css" href="/js/datatables/datatables.min.css" />
    <script type="text/javascript" src="/js/datatables/datatables.js"></script>

    <link rel="stylesheet" type="text/css" href="/js/overlay/imagemanager/oe-imagemanager.css" />
    <script type="text/javascript" src="/js/overlay/imagemanager/oe-imagemanager.js"></script>


    <link href="/js/dropzone/dropzone.css" type="text/css" rel="stylesheet" />
    <script src="/js/dropzone/dropzone-min.js"></script>

    <script src="/js/konva/konva.min.js"></script>

    <div id="oeeditor">
        <div class="row">
            <div id="oe-viewport" class="panel panel-primary">
                <div class="panel-heading"><i class="fa fa-code fa-edit"></i> Overlay Editor</div>


                <div>

                    <ul class="nav nav-tabs" role="tablist">
                        <li role="presentation" class="active"><a href="#oe-editor-tab" aria-controls="oe-editor-tab" role="tab" data-toggle="tab">Overlay Editor</a></li>
                        <li role="presentation"><a href="#oe-exposure-tab" aria-controls="oe-exposure-tab" role="tab" data-toggle="tab">Auto
                                Exposure Mask</a></li>
                    </ul>

                    <div class="tab-content">
                        <div role="tabpanel" class="tab-pane active" id="oe-editor-tab">
                            <nav class="navbar navbar-default">
                                <div class="container-fluid">
                                    <div class="collapse navbar-collapse" id="oe-main-navbar">
                                        <ul class="nav navbar-nav">
                                            <li>
                                                <div class="tooltip-wrapper disabled" data-toggle="tooltip" data-container="body" data-placement="top" title="Save The Current Configuration">
                                                    <div class="btn btn-lg navbar-btn glyphicon glyphicon-floppy-disk disabled" id="oe-save"></div>
                                                </div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-font" id="oe-add-text" data-toggle="tooltip" data-container="body" data-placement="top" title="Add New Text Field"></div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-picture" id="oe-add-image" data-toggle="tooltip" data-container="body" data-placement="top" title="Add New Image Field"></div>
                                            </li>
                                            <li>
                                                <div class="tooltip-wrapper disabled" data-toggle="tooltip" data-container="body" data-placement="top" title="Delete The Selected Field">
                                                    <div class="btn btn-lg navbar-btn glyphicon glyphicon-remove disabled" id="oe-delete"></div>
                                                </div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-list" id="oe-item-list" data-toggle="tooltip" data-container="body" data-placement="top" title="Display Available Variables"></div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-check" id="oe-test-mode" data-toggle="tooltip" data-container="body" data-placement="top" title="Display Sample Data"></div>
                                            </li>

                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-zoom-in oe-zoom" id="oe-zoom-in" data-toggle="tooltip" data-container="body" data-placement="top" title="Zoom in"></div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-zoom-out oe-zoom" id="oe-zoom-out" data-toggle="tooltip" data-container="body" data-placement="top" title="Zoom Out"></div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-resize-full oe-zoom" id="oe-zoom-full" data-toggle="tooltip" data-container="body" data-placement="top" title="View Full Size"></div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-resize-small oe-zoom" id="oe-zoom-fit" data-toggle="tooltip" data-container="body" data-placement="top" title="Fit to Window"></div>
                                            </li>
                                        </ul>
                                        <ul class="nav navbar-nav navbar-right">
                                            <li id="oe-toolbar-debug" class="hidden">
                                                <div id="oe-toobar-debug-button" class="btn btn-lg navbar-btn glyphicon glyphicon-wrench" data-toggle="tooltip" data-container="body" data-placement="top" title="Debug Info"></div>
                                            </li>
                                            <li>
                                                <div id="oe-upload-font" class="btn btn-lg navbar-btn glyphicon glyphicon-import" data-toggle="tooltip" data-container="body" data-placement="top" title="Font Manager"></div>
                                            </li>
                                            <li>
                                                <div id="oe-show-image-manager" class="btn btn-lg navbar-btn glyphicon glyphicon-upload" data-toggle="tooltip" data-container="body" data-placement="top" title="Image Manager"></div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-cog" id="oe-options" data-toggle="tooltip" data-container="body" data-placement="top" title="Layout and App Options">
                                                </div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-question-sign" id="oe-help" data-toggle="tooltip" data-container="body" data-placement="top" title="Help">
                                                </div>
                                            </li>

                                        </ul>
                                    </div>
                                </div>
                            </nav>
                            <div class="oe-editor panel-body">
                                <div id="overlay_container" style="background-color: black; margin-bottom: 15px; position: relative">
                                    <div id="oe-editor-stage"></div>
                                </div>
                            </div>
                        </div>
                        <div role="tabpanel" class="tab-pane" id="oe-exposure-tab">
                            <nav class="navbar navbar-default">
                                <div class="container-fluid">
                                    <div class="collapse navbar-collapse" id="oe-autoexposure-navbar">
                                        <ul class="nav navbar-nav">
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-floppy-disk" id="oe-savemask" data-toggle="tooltip" data-placement="top" data-container="body" title="Save The AutoExposure Mask"></div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-refresh" id="oe-autoexposure-reset" data-toggle="tooltip" data-placement="top" data-container="body" title="Reset The AutoExposure Mask"></div>
                                            </li>





                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-zoom-in oe-autoexposure-zoom" id="oe-autoexposure-zoom-in" data-toggle="tooltip" data-container="body" data-placement="top" title="Zoom in"></div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-zoom-out oe-autoexposure-zoom" id="oe-autoexposure-zoom-out" data-toggle="tooltip" data-container="body" data-placement="top" title="Zoom Out"></div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-resize-full oe-autoexposure-zoom" id="oe-autoexposure-zoom-full" data-toggle="tooltip" data-container="body" data-placement="top" title="View Full Size"></div>
                                            </li>
                                            <li>
                                                <div class="btn btn-lg navbar-btn glyphicon glyphicon-resize-small oe-autoexposure-zoom" id="oe-autoexposure-zoom-fit" data-toggle="tooltip" data-container="body" data-placement="top" title="Fit to Window"></div>
                                            </li>



                                        </ul>
                                    </div>
                                </div>
                            </nav>
                            <div class="oe-maskeditor panel-body">
                                <div id="mask_container" style="background-color: black; margin-bottom: 15px; position: relative">
                                    <div id="oe-exposure-stage"></div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div id="textdialog" title="Text Properties">
                <div id="textpropgrid"></div>
            </div>

            <div id="imagedialog" title="Image Properties">
                <div id="imagepropgrid"></div>
            </div>

            <div id="helpdialog" title="Help">
                <div id="helptext"></div>
            </div>

            <div id="oe-app-helpdialog" title="Overlay Editor Help">
                <div id="oeapphelptext"></div>
            </div>

            <div class="modal" role="dialog" id="oe-item-list-dialog">
                <div class="modal-dialog modal-lg" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                            <h4 class="modal-title">Available Variables</h4>
                        </div>
                        <div class="modal-body">
                            <table id="itemlisttable" class="display compact" style="width:98%">
                                <thead>
                                    <tr>
                                        <th>id</th>
                                        <th>Variable Name</th>
                                        <th>Description</th>
                                        <th>Format</th>
                                        <th>Type</th>
                                        <th>Source</th>
                                        <th>&nbsp;</th>
                                    </tr>
                                </thead>
                            </table>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-primary pull-left" id="oe-field-dialog-add-field">Add Variable</button>
                            <button type="button" class="btn btn-default" id="oe-item-list-dialog-close">Close</button>
                            <button type="button" class="btn btn-primary hidden" id="oe-item-list-dialog-save">Save Changes</button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="modal" id="oe-item-list-edit-dialog">
                <div class="modal-dialog" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                            <h4 class="modal-title" id="oe-variable-edit-title">Edit Item</h4>
                        </div>
                        <div class="modal-body">
                            <p class="bg-danger oe-flash" id="oe-variable-edit-fash">You are editing a system field. You may only change the description, format and sample data values.</p>
                            <form id="oe-item-list-edit-dialog-form" class="form-horizontal">
                                <input type="hidden" id="oe-item-list-edit-dialog-id" name="oe-item-list-edit-dialog-id">
                                <div class="form-group">
                                    <label for="oe-item-list-edit-dialog-name" class="control-label col-xs-4">Variable Name</label>
                                    <div class="col-xs-8">
                                        <div class="input-group">
                                            <input id="oe-item-list-edit-dialog-name" name="oe-item-list-edit-dialog-name" class="form-control">
                                        </div>
                                    </div>
                                </div>
                                <div class="form-group">
                                    <label for="oe-item-list-edit-dialog-description" class="control-label col-xs-4">Description</label>
                                    <div class="col-xs-8">
                                        <div class="input-group">
                                            <input id="oe-item-list-edit-dialog-description" name="oe-item-list-edit-dialog-description" class="form-control">
                                        </div>
                                    </div>
                                </div>
                                <div class="form-group">
                                    <label for="oe-item-list-edit-dialog-format" class="control-label col-xs-4">Format</label>
                                    <div class="col-xs-8">
                                        <div class="input-group">
                                            <input id="oe-item-list-edit-dialog-format" name="oe-item-list-edit-dialog-format" class="form-control">
                                        </div>
                                    </div>
                                </div>
                                <div class="form-group">
                                    <label for="oe-item-list-edit-dialog-sample" class="control-label col-xs-4">Sample Data</label>
                                    <div class="col-xs-8">
                                        <div class="input-group">
                                            <input id="oe-item-list-edit-dialog-sample" name="oe-item-list-edit-dialog-sample" class="form-control">
                                        </div>
                                    </div>
                                </div>
                                <div class="form-group">
                                    <label for="oe-item-list-edit-dialog-type" class="col-sm-4 control-label">Type</label>
                                    <div class="col-sm-8">
                                        <div class="input-group">
                                            <select class="form-control" id="oe-item-list-edit-dialog-type" name="oe-item-list-edit-dialog-type">
                                                <option value="Date">Date</option>
                                                <option value="Time">Time</option>
                                                <option value="Number">Number</option>
                                                <option value="Text">Text</option>
                                            </select>
                                        </div>
                                    </div>
                                </div>
                                <div class="form-group hidden">
                                    <label for="oe-item-list-edit-dialog-source" class="col-sm-4 control-label">Source</label>
                                    <div class="col-sm-8">
                                        <div class="input-group">
                                            <select class="form-control" id="oe-item-list-edit-dialog-source" name="oe-item-list-edit-dialog-source" disabled="disabled">
                                                <option value="System">System</option>
                                                <option value="User">User</option>
                                            </select>
                                        </div>
                                    </div>
                                </div>
                            </form>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                            <button type="button" id="oe-field-save" class="btn btn-primary">Save changes</button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="modal" role="dialog" id="fontlistdialog">
                <div class="modal-dialog modal-lg" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                            <h4 class="modal-title">Font Manager</h4>
                        </div>
                        <div class="modal-body">
                            <table id="fontlisttable" class="display compact" style="width:98%">
                                <thead>
                                    <tr>
                                        <th>Name</th>
                                        <th>Path</th>
                                        <th>&nbsp;</th>
                                    </tr>
                                </thead>
                            </table>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-primary pull-left" id="oe-font-dialog-add-font">Add Font</button>
                            <button type="button" class="btn btn-primary pull-left" id="oe-font-dialog-upload-font">Upload Font</button>
                            <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="modal" role="dialog" id="oe-file-manager-dialog">
                <div class="modal-dialog modal-lg" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                            <h4 class="modal-title">Image Manager</h4>
                        </div>
                        <div class="modal-body">
                            <div id="oe-image-manager"></div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-default" id="oe-file-manager-dialog-close" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="modal" role="dialog" id="oe-debug-dialog">
                <div class="modal-dialog modal-lg" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                            <h4 class="modal-title">Debug Info</h4>
                        </div>
                        <div class="modal-body">
                            <form id="oe-debug-dialog-form" class="form-horizontal">
                                <div class="form-group">
                                    <label for="oe-debug-dialog-overlay" class="col-sm-2 control-label">Overlay Data</label>
                                    <div class="col-sm-10">
                                        <div class="input-group">
                                            <textarea id="oe-debug-dialog-overlay" name="oe-debug-dialog-overlay" rows="10" cols="80" disabled="disabled"></textarea>
                                        </div>
                                    </div>
                                </div>
                                <div class="form-group">
                                    <label for="oe-debug-dialog-fields" class="col-sm-2 control-label">Field Data</label>
                                    <div class="col-sm-10">
                                        <div class="input-group">
                                            <textarea id="oe-debug-dialog-fields" name="oe-debug-dialog-fields" rows="10" cols="80" disabled="disabled"></textarea>
                                        </div>
                                    </div>
                                </div>
                                <div class="form-group">
                                    <label for="oe-debug-dialog-config" class="col-sm-2 control-label">Editor Config</label>
                                    <div class="col-sm-10">
                                        <div class="input-group">
                                            <textarea id="oe-debug-dialog-config" name="oe-debug-dialog-config" rows="10" cols="80" disabled="disabled"></textarea>
                                        </div>
                                    </div>
                                </div>                                
                            </form>                          
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>

        </div>

        <div class="modal" tabindex="-1" id="optionsdialog">
            <div class="modal-dialog modal-lg" role="document">
                <div class="modal-content">
                    <div class="modal-header">
                        <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                        <h4 class="modal-title">Overlay Editor Options</h4>
                    </div>
                    <div class="modal-body">



                        <div>

                            <!-- Nav tabs -->
                            <ul class="nav nav-tabs" role="tablist">
                                <li role="presentation" class="active"><a href="#configoptions" aria-controls="configoptions" role="tab" data-toggle="tab">Layout Defaults</a></li>
                                <li role="presentation"><a href="#oeeditoroptions" aria-controls="oeeditoroptions" role="tab" data-toggle="tab">Editor Settings</a></li>
                            </ul>

                            <!-- Tab panes -->
                            <div class="tab-content">
                                <div role="tabpanel" class="tab-pane active" id="configoptions">
                                    <br />

                                    <form id="oe-defaults-form" class="form-horizontal">
                                        <div class="form-group">
                                            <label for="defaultimagetopacity" class="control-label col-xs-4">Default Image
                                                Opacity</label>
                                            <div class="col-xs-8">
                                                <div class="input-group">
                                                    <input id="defaultimagetopacity" name="defaultimagetopacity" type="number" min="0" max="100" step="1" class="form-control">
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="defaultimagerotation" class="control-label col-xs-4">Default Image
                                                Rotation</label>
                                            <div class="col-xs-8">
                                                <div class="input-group">
                                                    <input id="defaultimagerotation" name="defaultimagerotation" type="text" class="form-control">
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="defaultfont" class="control-label col-xs-4">Default Font</label>
                                            <div class="col-xs-8">
                                                <div class="input-group">
                                                    <select id="defaultfont" name="defaultfont" class="form-control">
                                                    </select>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="defaultfontsize" class="control-label col-xs-4">Default Font
                                                Size</label>
                                            <div class="col-xs-8">
                                                <div class="input-group">
                                                    <input id="defaultfontsize" name="defaultfontsize" type="number" min="8" max="64" step="1" class="form-control">
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="defaultfontopacity" class="control-label col-xs-4">Default Font
                                                Opacity</label>
                                            <div class="col-xs-8">
                                                <div class="input-group">
                                                    <input id="defaultfontopacity" name="defaultfontopacity" type="number" min="0" max="100" step="1" class="form-control">
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="oe-default-font-colour" class="control-label col-xs-4">Default Font
                                                Colour</label>
                                            <div class="col-xs-8">
                                                <div class="input-group">
                                                    <input id="oe-default-font-colour" name="oe-default-font-colour" type="input" class="form-control">
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="defaulttextrotation" class="control-label col-xs-4">Default Text
                                                Rotation</label>
                                            <div class="col-xs-8">
                                                <div class="input-group">
                                                    <input id="defaulttextrotation" name="defaulttextrotation" type="number" min="0" max="359" step="1" class="form-control">
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="defaultdatafileexpiry" class="control-label col-xs-4">Default Extra Data Expiry</label>
                                            <div class="col-xs-8">
                                                <div class="input-group">
                                                    <input id="defaultdatafileexpiry" name="defaultdatafileexpiry" type="number" min="0" max="60000" step="10" class="form-control">
                                                </div>
                                                <p class="help-block">This is the default expiry time in seconds for the extra data files. This can be overriden for each variable in the data files, see the documentation for more details</p>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="defaultnoradids" class="control-label col-xs-4">Norad ID's</label>
                                            <div class="col-xs-8">
                                                <div class="input-group">
                                                    <input id="defaultnoradids" name="defaultnoradids" type="text" class="form-control">
                                                </div>
                                                <p class="help-block">List of NORAD Id's to calculate satellite positions for. See the documentaiton for mroe details</p>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <div class="col-sm-offset-4 col-sm-2">
                                                <div class="checkbox">
                                                    <label>
                                                        <input type="checkbox" id="defaultincludeplanets"> Include Planets
                                                    </label>
                                                </div>
                                            </div>
                                            <div class="col-sm-2">
                                                <div class="checkbox">
                                                    <label>
                                                        <input type="checkbox" id="defaultincludesun"> Include Sun
                                                    </label>
                                                </div>
                                            </div>  
                                            <div class="col-sm-4">
                                                <div class="checkbox">
                                                    <label>
                                                        <input type="checkbox" id="defaultincludemoon"> Include Moon
                                                    </label>
                                                </div>
                                            </div>                                                                                         
                                        </div>                                                                             
                                    </form>

                                </div>

                                <div role="tabpanel" class="tab-pane" id="oeeditoroptions">
                                    <br />

                                    <form id="oe-app-settings-form" class="form-horizontal">
                                        <div class="form-group">
                                            <div class="col-sm-offset-4 col-sm-8">
                                                <div class="checkbox">
                                                    <label>
                                                        <input type="checkbox" id="oe-app-options-show-grid"> Show Grid
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="oe-app-options-grid-size" class="col-sm-4 control-label">Grid Size</label>
                                            <div class="col-sm-8">
                                                <div class="input-group">
                                                    <select class="form-control" id="oe-app-options-grid-size" name="oe-app-options-grid-size">
                                                        <option value="0">None</option>
                                                        <option value="5">5x5</option>
                                                        <option value="10">10x10</option>
                                                        <option value="15">15x15</option>
                                                        <option value="20">20x20</option>
                                                        <option value="25">25x25</option>
                                                        <option value="30">30x30</option>
                                                        <option value="35">35x35</option>
                                                        <option value="40">40x40</option>
                                                        <option value="45">45x45</option>
                                                        <option value="50">50x50</option>
                                                    </select>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="oe-app-options-grid-opacity" class="col-sm-4 control-label">Grid Opacity</label>
                                            <div class="col-sm-8">
                                                <div class="input-group">
                                                    <input id="oe-app-options-grid-opacity" name="oe-app-options-grid-opacity" type="number" min="0" max="100" step="5" class="form-control">

                                                </div>
                                                <p class="help-block">0 = Black, 100 = White</p>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <div class="col-sm-offset-4 col-sm-8">
                                                <div class="checkbox">
                                                    <label>
                                                        <input type="checkbox" id="oe-app-options-snap-background"> Show Snap Rectangle
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="oe-app-options-add-list-size" class="col-sm-4 control-label">Add List Page Size</label>
                                            <div class="col-sm-8">
                                                <div class="input-group">
                                                    <select class="form-control" id="oe-app-options-add-list-size" name="oe-app-options-add-list-size">
                                                        <option value="5">5</option>
                                                        <option value="10">10</option>
                                                        <option value="15">15</option>
                                                        <option value="20">20</option>
                                                        <option value="25">25</option>
                                                        <option value="30">30</option>
                                                        <option value="35">35</option>
                                                        <option value="40">40</option>
                                                        <option value="45">45</option>
                                                        <option value="50">50</option>
                                                    </select>
                                                </div>
                                            </div>
                                        </div>

                                        <div class="form-group">
                                            <label for="oe-app-options-add-field-opacity" class="col-sm-4 control-label">Add Field Opacity</label>
                                            <div class="col-sm-8">
                                                <div class="input-group">
                                                    <input id="oe-app-options-add-field-opacity" name="oe-app-options-add-field-opacity" type="number" min="0" max="100" step="5" class="form-control">
                                                </div>
                                                <p class="help-block">The opacity existing fields will be set to when adding a field. 0 = Black, 100 = White</p>
                                            </div>
                                        </div>


                                        <div class="form-group">
                                            <label for="oe-app-options-select-field-opacity" class="col-sm-4 control-label">Select Field Opacity</label>
                                            <div class="col-sm-8">
                                                <div class="input-group">
                                                    <input id="oe-app-options-select-field-opacity" name="oe-app-options-select-field-opacity" type="number" min="0" max="100" step="5" class="form-control">
                                                </div>
                                                <p class="help-block">The opacity existing fields will be set to when selecting a field. 0 = Black, 100 = White</p>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <div class="col-sm-offset-4 col-sm-8">
                                                <div class="checkbox">
                                                    <label>
                                                        <input type="checkbox" id="oe-app-options-mousewheel-zoom"> Zoom with Mouse Wheel
                                                    </label>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <label for="oe-app-options-background-opacity" class="col-sm-4 control-label">Background Image Opacity</label>
                                            <div class="col-sm-8">
                                                <div class="input-group">
                                                    <input id="oe-app-options-background-opacity" name="oe-app-options-background-opacity" type="number" min="0" max="100" step="10" class="form-control">
                                                </div>
                                                <p class="help-block">0 = Black, 100 = White</p>
                                            </div>
                                        </div>
                                        <div class="form-group">
                                            <div class="col-sm-offset-4 col-sm-8">
                                                <div class="checkbox">
                                                    <label>
                                                        <input type="checkbox" id="oe-app-options-debug"> Enable Debug Mode
                                                    </label>
                                                </div>
                                            </div>
                                        </div>                                        
                                    </form>

                                </div>
                            </div>
                        </div>

                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                        <button type="button" id="oe-defaults-save" class="btn btn-primary">Save changes</button>
                    </div>
                </div><!-- /.modal-content -->
            </div><!-- /.modal-dialog -->
        </div>

        <div class="modal" role="dialog" id="fontuploaddialog">
            <div class="modal-dialog modal-lg" role="document">
                <div class="modal-content">
                    <div class="modal-header">
                        <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                        <h4 class="modal-title">Upload Font</h4>
                    </div>
                    <div class="modal-body">
                        <div>
                            <div>
                                <p>NOTE: The zip file must contain ONLY font files. Fonts in directories within the zip file are NOT supported</p>
                            </div>

                            <form enctype="multipart/form-data" id="fupForm" >
                                <div class="form-group">
                                    <label for="fontuploadfile" class="control-label col-xs-2">File</label>
                                    <div class="col-xs-6">
                                        <div class="input-group">
                                            <input type="file" class="form-control" id="fontuploadfile" name="fontuploadfile" required />
                                        </div>
                                    </div>
                                    <div class="col-xs-4">
                                        <div class="input-group">
                                        <input type="submit" name="submit" class="btn btn-danger submitBtn" value="SAVE"/>
                                        </div>
                                    </div>
                                </div>
                            </form>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                    </div>
                </div>
            </div>
        </div>

        <img id="oe-background-image" class="oe-background-image" src="<?php echo $image_name ?>" style="width:100%">

        <script type="module">
            var overlayEditor = new OVERLAYEDITOR($("#overlay_container"));
            await overlayEditor.buildUI();

            var exposureEditor = new OEEXPOSURE();
            exposureEditor.start();
        </script>

    <?php
}
    ?>