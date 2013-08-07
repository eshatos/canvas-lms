define [
  'i18n!assignments'
  'underscore'
  'compiled/models/AssignmentGroup'
  'compiled/views/DialogFormView'
  'jst/assignments/DeleteGroup'
  'jst/EmptyDialogFormWrapper'
], (I18n, _, AssignmentGroup, DialogFormView, template, wrapper) ->

  class DeleteGroupView extends DialogFormView

    defaults:
      width: 500
      height: 275

    els:
      '.assignment_count': '$assignmentCount'
      '.group_select': '$groupSelect'

    events: _.extend({}, @::events,
      'click .dialog_closer': 'close'
      'click .delete_group': 'destroy'
      'change .group_select': 'selectMove'
    )

    template: template
    wrapperTemplate: wrapper

    @optionProperty 'assignments'

    initialize: ->
      super
      @assignments.on 'add remove', @updateAssignmentCount
      @model.collection.on 'add', @addToGroupOptions
      @model.collection.on 'remove', @removeFromGroupOptions

    toJSON: ->
      data = super
      groups = @model.collection.reject (model) =>
        model.get('id') == @model.get('id')
      groups_json = groups.map (model) ->
        model.toJSON()

      _.extend(data, {
        assignment_count: @assignments.length
        groups: groups_json
        label_id: data.id
      })

    updateAssignmentCount: =>
      @$assignmentCount.text(@assignments.length)

    addToGroupOptions: (model) =>
      id = model.get('id')
      $opt = $('<option>')
      $opt.val(id)
      $opt.addClass("ag_#{id}")
      $opt.text(model.get('name'))
      @$groupSelect.append $opt

    removeFromGroupOptions: (model) =>
      id = model.get('id')
      @$groupSelect.find("move_to_ag_#{id}").remove()

    destroy: ->
      data = @getFormData()
      if data.action == "move" && data.move_assignments_to
        @destroyModel(data.move_assignments_to)
        @close()

      if data.action == "delete"
        @destroyModel()
        @close()

    destroyModel: (moveTo=null) ->
      @collection = @model.collection
      data = if moveTo then "move_assignments_to=#{moveTo}" else ''
      if moveTo
        #delay the fetch until the destroy request is done
        @model.on('sync', @refreshCollection)
      @model.destroy({data: data})
      @collection.view.render()

    refreshCollection: (model,xhr,options) =>
      @collection.fetch()

    selectMove: ->
      if !@$el.find(".group_select :selected").hasClass("blank")
        @$el.find('.assignment_group_move').prop('checked', true)

    openAgain: ->
      # make sure there is more than one assignment group
      if @model.collection.models.length > 1
        # check if it has assignments
        if @assignments.length > 0
          super
        else
          # no assignments, so just confirm
          if confirm I18n.t('confirm_delete_group', "Are you sure you want to delete this Assignment Group?")
            @destroyModel()
      else
        # last assignment group, so alert, but don't destroy
        alert I18n.t('cannot_delete_group', "You must have at least one Assignment Group")