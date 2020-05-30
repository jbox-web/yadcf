((factory) ->
  'use strict'
  if typeof define == 'function' and define.amd
    # AMD
    define [ 'jquery' ], ($) ->
      factory $, window, document

  else if typeof module == 'object'
    # CommonJS
    module.exports = (root, $) ->
      if !root
        # CommonJS environments without a window global must pass a
        # root. This will give an error otherwise
        root = window
      if !$
        $ = if typeof window != 'undefined' then require('jquery') else require('jquery')(root)
      factory $, root, root.document

  else
    # Browser
    factory jQuery, window, document

) ($, window, document) ->

  if window
    moment = window.moment

  yadcf = do ->

    'use strict'

    tablesDT = {}
    oTables = {}
    oTablesIndex = {}
    options = {}
    plugins = {}
    exFilterColumnQueue = []
    yadcfDelay = undefined
    reA = /[^a-zA-Z]/g
    reN = /[^0-9]/g
    selectElementCustomInitFunc = undefined
    selectElementCustomRefreshFunc = undefined
    selectElementCustomDestroyFunc = undefined

    getSettingsObjFromTable = (dt) ->
      oDTSettings = undefined
      if $.fn.dataTable.Api
        oDTSettings = new ($.fn.dataTable.Api)(dt).settings()[0]
      else if dt.fnSettings
        # 1.9 compatibility
        # DataTables object, convert to the settings object
        oDTSettings = dt.fnSettings()
      else if typeof dt == 'string'
        # jQuery selector
        if $.fn.dataTable.fnIsDataTable($(dt)[0])
          oDTSettings = $(dt).eq(0).dataTable().fnSettings()
      else if dt.nodeName and dt.nodeName.toLowerCase() == 'table'
        # Table node
        if $.fn.dataTable.fnIsDataTable(dt.nodeName)
          oDTSettings = $(dt.nodeName).dataTable().fnSettings()
      else if dt instanceof jQuery
        # jQuery object
        if $.fn.dataTable.fnIsDataTable(dt[0])
          oDTSettings = dt.eq(0).dataTable().fnSettings()
      else
        # DataTables settings object
        oDTSettings = dt
      oDTSettings

    arraySwapValueWithIndex = (pArray) ->
      tmp = []
      i = undefined
      i = 0
      while i < pArray.length
        tmp[pArray[i]] = i
        i++
      tmp

    arraySwapValueWithIndex2 = (pArray) ->
      tmp = []
      i = undefined
      i = 0
      while i < pArray.length
        tmp[pArray[i]._ColReorder_iOrigCol] = i
        i++
      tmp

    initColReorder2 = (settingsDt, table_selector_jq_friendly) ->
      if settingsDt.oSavedState? and settingsDt.oSavedState.ColReorder?
        if plugins[table_selector_jq_friendly] == undefined
          plugins[table_selector_jq_friendly] = {}
          plugins[table_selector_jq_friendly].ColReorder = arraySwapValueWithIndex(settingsDt.oSavedState.ColReorder)
      else if settingsDt.aoColumns[0]._ColReorder_iOrigCol?
        if plugins[table_selector_jq_friendly] == undefined
          plugins[table_selector_jq_friendly] = {}
          plugins[table_selector_jq_friendly].ColReorder = arraySwapValueWithIndex2(settingsDt.aoColumns)
      return

    initColReorderFromEvent = (table_selector_jq_friendly) ->
      plugins[table_selector_jq_friendly] = undefined
      return

    columnsArrayToString = (column_number) ->
      column_number_obj = {}
      if column_number?
        if column_number instanceof Array
          column_number_obj.column_number_str = column_number.join('_')
        else
          column_number_obj.column_number_str = column_number
          column_number = []
          column_number.push column_number_obj.column_number_str
      else
        column_number_obj.column_number_str = 'global'
      column_number_obj.column_number = column_number
      column_number_obj

    getOptions = (selector) ->
      options[selector]

    eventTargetFixUp = (pEvent) ->
      if pEvent.target == undefined
        pEvent.target = pEvent.srcElement
      pEvent

    dot2obj = (tmpObj, dot_refs) ->
      i = 0
      dot_refs = dot_refs.split('.')
      i = 0
      while i < dot_refs.length
        tmpObj = tmpObj[dot_refs[i]]
        i++
      tmpObj

    setOptions = (selector_arg, options_arg, params) ->
      tmpOptions = {}
      i = undefined
      j = undefined
      col_num_as_int = undefined
      default_options =
        filter_type: 'select'
        enable_auto_complete: false
        sort_as: 'alpha'
        sort_order: 'asc'
        date_format: 'mm/dd/yyyy'
        ignore_char: undefined
        filter_match_mode: 'contains'
        select_type: undefined
        select_type_options: {}
        case_insensitive: true
        column_data_type: 'text'
        html_data_type: 'text'
        exclude_label: 'exclude'
        style_class: ''
        datepicker_type: 'jquery-ui'
        range_data_type: 'single'
        range_data_type_delim: '-'

      adaptContainerCssClassImpl = (dummy) ->
        ''

      $.extend true, default_options, params
      if options_arg.length == undefined
        options[selector_arg] = options_arg
        return
      i = 0
      while i < options_arg.length
        if options_arg[i].select_type == 'select2'
          default_options.select_type_options = adaptContainerCssClass: adaptContainerCssClassImpl
        #no individual reset button for externally_triggered mode
        if default_options.externally_triggered == true
          options_arg[i].filter_reset_button_text = false
        #validate custom function required attributes
        if options_arg[i].filter_type? and options_arg[i].filter_type.indexOf('custom_func') != -1
          if options_arg[i].custom_func == undefined
            console.log 'Error: You are trying to use filter_type: "custom_func / multi_select_custom_func" for column ' + options_arg[i].column_number + ' but there is no such custom_func attribute provided (custom_func: "function reference goes here...")'
            return
        col_num_as_int = +options_arg[i].column_number
        if isNaN(col_num_as_int)
          tmpOptions[options_arg[i].column_number_str] = $.extend(true, {}, default_options, options_arg[i])
        else
          tmpOptions[col_num_as_int] = $.extend(true, {}, default_options, options_arg[i])
        i++
      options[selector_arg] = tmpOptions
      return

    yadcfVersionCheck = (version) ->
      aThis = $.fn.dataTable.ext.sVersion.split('.')
      aThat = version.split('.')
      iThis = undefined
      iThat = undefined
      i = undefined
      iLen = undefined
      i = 0
      iLen = aThat.length
      while i < iLen
        iThis = parseInt(aThis[i], 10) or 0
        iThat = parseInt(aThat[i], 10) or 0

        # Parts are the same, keep comparing
        if iThis == iThat
          i++
          continue

        # Parts are different, return immediately
        return iThis > iThat

      true

    calculateColumnNumber = (column_number, pTable) ->
      col_num_visible_iter = undefined
      col_num_visible = column_number
      col_num_visible_iter = 0
      while col_num_visible_iter < pTable.fnSettings().aoColumns.length and col_num_visible_iter < column_number
        if pTable.fnSettings().aoColumns[col_num_visible_iter].bVisible == false
          col_num_visible++
        col_num_visible_iter++
      col_num_visible

    resetIApiIndex = ->
      $.fn.dataTableExt.iApiIndex = 0
      return

    escapeRegExp = (string) ->
      string.replace /([.*+?^=!:${}()|\[\]\/\\])/g, '\\$1'

    replaceAll = (string, find, replace) ->
      string.replace new RegExp(escapeRegExp(find), 'g'), replace

    generateTableSelectorJQFriendly = (tmpStr) ->
      tmpStr = replaceAll(tmpStr, '.', '-')
      tmpStr = replaceAll(tmpStr, ' ', '')
      tmpStr.replace(':', '-').replace('(', '').replace(')', '').replace '#', '-'

    generateTableSelectorJQFriendlyNew = (tmpStr) ->
      tmpStr = replaceAll(tmpStr, ':', '-')
      tmpStr = replaceAll(tmpStr, '(', '')
      tmpStr = replaceAll(tmpStr, ')', '')
      tmpStr = replaceAll(tmpStr, ',', '')
      tmpStr = replaceAll(tmpStr, '.', '-')
      tmpStr = replaceAll(tmpStr, '#', '-')
      tmpStr

    initializeSelectPlugin = (selectType, $selectObject, select_type_options) ->
      if selectType == 'chosen'
        $selectObject.chosen select_type_options
        $selectObject.next().attr('onclick', 'yadcf.stopPropagation(event);').attr 'onmousedown', 'yadcf.stopPropagation(event);'
      else if selectType == 'select2'
        $selectObject.select2 select_type_options
        if $selectObject.next().hasClass('select2-container')
          $selectObject.next().attr('onclick', 'yadcf.stopPropagation(event);').attr 'onmousedown', 'yadcf.stopPropagation(event);'
      else if selectType == 'custom_select'
        selectElementCustomInitFunc $selectObject
        $selectObject.next().attr('onclick', 'yadcf.stopPropagation(event);').attr 'onmousedown', 'yadcf.stopPropagation(event);'
      return

    refreshSelectPlugin = (columnObj, $selectObject, val) ->
      selectType = columnObj.select_type
      select_type_options = columnObj.select_type_options
      if selectType == 'chosen'
        $selectObject.trigger 'chosen:updated'
      else if selectType == 'select2'
        $selectObject.select2 select_type_options
        $selectObject.val val
      else if selectType == 'custom_select'
        selectElementCustomRefreshFunc $selectObject
      return

    initSelectPluginCustomTriggers = (initFunc, refreshFunc, destroyFunc) ->
      selectElementCustomInitFunc = initFunc
      selectElementCustomRefreshFunc = refreshFunc
      selectElementCustomDestroyFunc = destroyFunc
      return

    yadcfMatchFilterString = (table_arg, column_number, selected_value, filter_match_mode, multiple, exclude) ->
      case_insensitive = yadcf.getOptions(table_arg.selector)[column_number].case_insensitive
      ret_val = undefined
      table_arg.fnSettings().aoPreSearchCols[column_number].bSmart = false
      table_arg.fnSettings().aoPreSearchCols[column_number].bRegex = true
      table_arg.fnSettings().aoPreSearchCols[column_number].bCaseInsensitive = case_insensitive
      if multiple == undefined or multiple == false
        if exclude != true
          if filter_match_mode == 'contains'
            table_arg.fnSettings().aoPreSearchCols[column_number].bSmart = true
            table_arg.fnSettings().aoPreSearchCols[column_number].bRegex = false
            ret_val = selected_value
          else if filter_match_mode == 'exact'
            ret_val = '^' + selected_value + '$'
          else if filter_match_mode == 'startsWith'
            ret_val = '^' + selected_value
          else if filter_match_mode == 'regex'
            ret_val = selected_value
        else
          ret_val = '^((?!' + selected_value + ').)*$'
      else
        if filter_match_mode == 'contains'
          ret_val = selected_value.join('|')
        else if filter_match_mode == 'exact'
          ret_val = '^(' + selected_value.join('|') + ')$'
        else if filter_match_mode == 'startsWith'
          ret_val = '^(' + selected_value.join('|') + ')'
        else if filter_match_mode == 'regex'
          ret_val = selected_value
      ret_val

    yadcfMatchFilter = (oTable, selected_value, filter_match_mode, column_number, exclude) ->
      case_insensitive = yadcf.getOptions(oTable.selector)[column_number].case_insensitive
      if exclude != true
        if filter_match_mode == 'contains'
          oTable.fnFilter selected_value, column_number, false, true, true, case_insensitive
        else if filter_match_mode == 'exact'
          selected_value = escapeRegExp(selected_value)
          oTable.fnFilter '^' + selected_value + '$', column_number, true, false, true, case_insensitive
        else if filter_match_mode == 'startsWith'
          selected_value = escapeRegExp(selected_value)
          oTable.fnFilter '^' + selected_value, column_number, true, false, true, case_insensitive
        else if filter_match_mode == 'regex'
          try
            #validate regex, only call fnFilter if valid
            new RegExp(selected_value)
          catch error
            return
          oTable.fnFilter selected_value, column_number, true, false, true, case_insensitive
      else
        oTable.fnFilter '^((?!' + selected_value + ').)*$', column_number, true, false, true, case_insensitive
      return

    yadcfParseMatchFilter = (tmpStr, filter_match_mode) ->
      retVal = undefined
      if filter_match_mode == 'contains'
        retVal = tmpStr
      else if filter_match_mode == 'exact'
        retVal = tmpStr.substring(1, tmpStr.length - 1)
        retVal = retVal.replace(/([\\])/g, '')
      else if filter_match_mode == 'startsWith'
        retVal = tmpStr.substring(1, tmpStr.length)
        retVal = retVal.replace(/([\\])/g, '')
      else if filter_match_mode == 'regex'
        retVal = tmpStr
      retVal

    doFilterCustomDateFunc = (arg, table_selector_jq_friendly, column_number) ->
      oTable = oTables[table_selector_jq_friendly]
      yadcfState = undefined
      columnObj = getOptions(oTable.selector)[column_number]
      if arg == 'clear' and exGetColumnFilterVal(oTable, column_number) == ''
        return
      if arg.value? and arg.value != '-1'
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).addClass 'inuse'
      else
        #wehn arg === 'clear' or arg.value === '-1'
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val('-1').focus()
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).removeClass 'inuse'
        refreshSelectPlugin columnObj, $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number), '-1'
      if !oTable.fnSettings().oLoadedState
        oTable.fnSettings().oLoadedState = {}
        oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
      if oTable.fnSettings().oFeatures.bStateSave == true
        if oTable.fnSettings().oLoadedState.yadcfState? and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly]?
          oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number] = 'from': arg.value
        else
          yadcfState = {}
          yadcfState[table_selector_jq_friendly] = []
          yadcfState[table_selector_jq_friendly][column_number] = 'from': arg.value
          oTable.fnSettings().oLoadedState.yadcfState = yadcfState
        oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
      oTable.fnDraw()
      return

    calcColumnNumberFilter = (settingsDt, column_number, table_selector_jq_friendly) ->
      column_number_filter = undefined
      if settingsDt.oSavedState? and settingsDt.oSavedState.ColReorder? or settingsDt._colReorder? or plugins[table_selector_jq_friendly]? and plugins[table_selector_jq_friendly].ColReorder?
        initColReorder2 settingsDt, table_selector_jq_friendly
        column_number_filter = plugins[table_selector_jq_friendly].ColReorder[column_number]
      else
        column_number_filter = column_number
      column_number_filter

    doFilter = (arg, table_selector_jq_friendly, column_number, filter_match_mode) ->
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      selected_value = undefined
      column_number_filter = undefined
      columnObj = undefined
      settingsDt = getSettingsObjFromTable(oTable)
      column_number_filter = calcColumnNumberFilter(settingsDt, column_number, table_selector_jq_friendly)
      columnObj = getOptions(oTable.selector)[column_number]
      if arg == 'clear'
        if exGetColumnFilterVal(oTable, column_number) == ''
          return
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val('-1').focus()
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).removeClass 'inuse'
        $(document).data '#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val', '-1'
        oTable.fnFilter '', column_number_filter
        resetIApiIndex()
        refreshSelectPlugin columnObj, $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number), '-1'
        return
      $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).addClass 'inuse'
      $(document).data '#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val', arg.value
      selected_value = $.trim($(arg).find('option:selected').val())
      if arg.value != '-1'
        yadcfMatchFilter oTable, selected_value, filter_match_mode, column_number_filter
      else
        oTable.fnFilter '', column_number_filter
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).removeClass 'inuse'
      resetIApiIndex()
      return

    doFilterMultiSelect = (arg, table_selector_jq_friendly, column_number, filter_match_mode) ->
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      selected_values = $(arg).val()
      selected_values_trimmed = []
      i = undefined
      stringForSearch = undefined
      column_number_filter = undefined
      settingsDt = getSettingsObjFromTable(oTable)
      column_number_filter = calcColumnNumberFilter(settingsDt, column_number, table_selector_jq_friendly)
      $(document).data '#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val', selected_values
      if selected_values?
        i = selected_values.length - 1
        while i >= 0
          if selected_values[i] == '-1'
            selected_values.splice i, 1
            break
          i--
        i = 0
        while i < selected_values.length
          selected_values_trimmed.push $.trim(selected_values[i])
          i++
        if selected_values_trimmed.length != 0
          stringForSearch = selected_values_trimmed.join('narutouzomaki')
          stringForSearch = stringForSearch.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, '\\$1')
          stringForSearch = stringForSearch.split('narutouzomaki').join('|')
          if filter_match_mode == 'contains'
            oTable.fnFilter stringForSearch, column_number_filter, true, false, true
          else if filter_match_mode == 'exact'
            oTable.fnFilter '^(' + stringForSearch + ')$', column_number_filter, true, false, true
          else if filter_match_mode == 'startsWith'
            oTable.fnFilter '^(' + stringForSearch + ')', column_number_filter, true, false, true
          else if filter_match_mode == 'regex'
            oTable.fnFilter stringForSearch, column_number_filter, true, false, true
        else
          oTable.fnFilter '', column_number_filter
      else
        oTable.fnFilter '', column_number_filter
      resetIApiIndex()
      return

    yadcfParseMatchFilterMultiSelect = (tmpStr, filter_match_mode) ->
      retVal = undefined
      if filter_match_mode == 'contains'
        retVal = tmpStr
      else if filter_match_mode == 'exact'
        retVal = tmpStr.substring(1, tmpStr.length - 1)
        retVal = retVal.substring(1, retVal.length - 1)
      else if filter_match_mode == 'startsWith'
        retVal = tmpStr.substring(1, tmpStr.length)
        retVal = retVal.substring(1, retVal.length - 1)
      else if filter_match_mode == 'regex'
        retVal = tmpStr
      retVal

    doFilterAutocomplete = (arg, table_selector_jq_friendly, column_number, filter_match_mode) ->
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      column_number_filter = undefined
      settingsDt = getSettingsObjFromTable(oTable)
      column_number_filter = calcColumnNumberFilter(settingsDt, column_number, table_selector_jq_friendly)
      if arg == 'clear'
        if exGetColumnFilterVal(oTable, column_number) == ''
          return
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val('').focus()
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).removeClass 'inuse'
        $(document).removeData '#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val'
        oTable.fnFilter '', column_number_filter
        resetIApiIndex()
        return
      $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).addClass 'inuse'
      $(document).data '#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val', arg.value
      yadcfMatchFilter oTable, arg.value, filter_match_mode, column_number_filter
      resetIApiIndex()
      return

    autocompleteSelect = (event, ui) ->
      event = eventTargetFixUp(event)
      table_column = event.target.id.replace('yadcf-filter-', '')
      dashIndex = table_column.lastIndexOf('-')
      table_selector_jq_friendly = table_column.substring(0, dashIndex)
      col_num = parseInt(table_column.substring(dashIndex + 1), 10)
      filter_match_mode = $(event.target).attr('filter_match_mode')
      doFilterAutocomplete ui.item, table_selector_jq_friendly, col_num, filter_match_mode
      return

    sortNumAsc = (a, b) ->
      a - b

    sortNumDesc = (a, b) ->
      b - a

    findMinInArray = (array, columnObj) ->
      narray = []
      i = undefined
      num = undefined
      i = 0
      while i < array.length
        if array[i]?
          if columnObj.ignore_char?
            array[i] = array[i].toString().replace(columnObj.ignore_char, '')
          if columnObj.range_data_type == 'single'
            num = +array[i]
          else
            num = array[i].split(columnObj.range_data_type_delim)
            num = num[0]
          if !isNaN(num)
            narray.push num
        i++
      Math.min.apply Math, narray

    findMaxInArray = (array, columnObj) ->
      narray = []
      i = undefined
      num = undefined
      i = 0
      while i < array.length
        if array[i]?
          if columnObj.ignore_char?
            array[i] = array[i].toString().replace(columnObj.ignore_char, '')
          if columnObj.range_data_type == 'single'
            num = +array[i]
          else
            num = array[i].split(columnObj.range_data_type_delim)
            num = num[1]
          if !isNaN(num)
            narray.push num
        i++
      Math.max.apply Math, narray

    addRangeNumberAndSliderFilterCapability = (table_selector_jq_friendly, fromId, toId, col_num, ignore_char, sliderMaxMin) ->
      $.fn.dataTableExt.afnFiltering.push (settingsDt, aData, iDataIndex, rowData) ->
        min = undefined
        max = undefined
        val = undefined
        retVal = false
        table_selector_jq_friendly_local = table_selector_jq_friendly
        current_table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendly(settingsDt.oInstance.selector)
        ignore_char_local = ignore_char
        column_data_type = undefined
        html_data_type = undefined
        i = undefined
        columnObj = undefined
        column_number_filter = undefined
        valFrom = undefined
        valTo = undefined
        if table_selector_jq_friendly_local != current_table_selector_jq_friendly
          return true
        columnObj = getOptions(settingsDt.oInstance.selector)[col_num]
        if columnObj.filter_type == 'range_number_slider'
          min = $('#' + fromId).text()
          max = $('#' + toId).text()
        else
          min = $('#' + fromId).val()
          max = $('#' + toId).val()
        column_number_filter = calcColumnNumberFilter(settingsDt, col_num, table_selector_jq_friendly)
        if rowData?
          aData = rowData
          if columnObj.column_number_data?
            column_number_filter = columnObj.column_number_data
            val = dot2obj(aData, column_number_filter)
          else
            val = aData[column_number_filter]
        else
          val = aData[column_number_filter]
        if !isFinite(min) or !isFinite(max)
          return true
        column_data_type = columnObj.column_data_type
        html_data_type = columnObj.html_data_type
        if column_data_type == 'html' or column_data_type == 'rendered_html'
          if html_data_type == undefined
            html_data_type = 'text'
          if $(val).length != 0
            switch html_data_type
              when 'text'
                val = $(val).text()
              when 'value'
                val = $(val).val()
              when 'id'
                val = val.id
              when 'selector'
                val = $(val).find(columnObj.html_data_selector).text()
        else
          if typeof val == 'object'
            if columnObj.html5_data?
              val = val['@' + columnObj.html5_data]
        if ignore_char_local?
          min = min.replace(ignore_char_local, '')
          max = max.replace(ignore_char_local, '')
          if val
            val = val.toString().replace(ignore_char_local, '')
          else
            val = ''
        #omit empty rows when filtering
        if columnObj.filter_type == 'range_number_slider'
          if val == '' and (+min != sliderMaxMin.min or +max != sliderMaxMin.max)
            return false
        else
          if val == '' and (min != '' or max != '')
            return false
        min = if min != '' then +min else min
        max = if max != '' then +max else max
        if columnObj.range_data_type == 'single'
          val = if val != '' then +val else val
          if min == '' and max == ''
            retVal = true
          else if min == '' and val <= max
            retVal = true
          else if min <= val and '' == max
            retVal = true
          else if min <= val and val <= max
            retVal = true
          else if val == '' or isNaN(val)
            retVal = true
        else if columnObj.range_data_type == 'range'
          val = val.split(columnObj.range_data_type_delim)
          valFrom = if val[0] != '' then +val[0] else val[0]
          valTo = if val[1] != '' then +val[1] else val[1]
          if min == '' and max == ''
            retVal = true
          else if min == '' and valTo <= max
            retVal = true
          else if min <= valFrom and '' == max
            retVal = true
          else if min <= valFrom and valTo <= max
            retVal = true
          else if (valFrom == '' or isNaN(valFrom)) and (valTo == '' or isNaN(valTo))
            retVal = true
        retVal
      return

    addCustomFunctionFilterCapability = (table_selector_jq_friendly, filterId, col_num) ->
      $.fn.dataTableExt.afnFiltering.push (settingsDt, aData, iDataIndex, stateVal) ->
        filterVal = $('#' + filterId).val()
        columnVal = undefined
        retVal = false
        table_selector_jq_friendly_local = table_selector_jq_friendly
        current_table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendly(settingsDt.oInstance.selector)
        custom_func = undefined
        column_number_filter = undefined
        if table_selector_jq_friendly_local != current_table_selector_jq_friendly or filterVal == '-1'
          return true
        column_number_filter = calcColumnNumberFilter(settingsDt, col_num, table_selector_jq_friendly)
        columnVal = if aData[column_number_filter] == '-' then 0 else aData[column_number_filter]
        custom_func = getOptions(settingsDt.oInstance.selector)[col_num].custom_func
        retVal = custom_func(filterVal, columnVal, aData)
        retVal
      return

    addRangeDateFilterCapability = (table_selector_jq_friendly, fromId, toId, col_num, date_format) ->
      $.fn.dataTableExt.afnFiltering.push (settingsDt, aData, iDataIndex, rowData) ->
        min = if document.getElementById(fromId)? then document.getElementById(fromId).value else ''
        max = if document.getElementById(toId)? then document.getElementById(toId).value else ''
        val = undefined
        retVal = false
        table_selector_jq_friendly_local = table_selector_jq_friendly
        current_table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendly(settingsDt.oInstance.selector)
        column_data_type = undefined
        html_data_type = undefined
        i = undefined
        columnObjKey = undefined
        columnObj = undefined
        column_number_filter = undefined
        min_time = undefined
        max_time = undefined
        dataRenderFunc = undefined
        if table_selector_jq_friendly_local != current_table_selector_jq_friendly
          return true
        columnObj = getOptions(settingsDt.oInstance.selector)[col_num]
        column_number_filter = calcColumnNumberFilter(settingsDt, col_num, table_selector_jq_friendly)
        if typeof columnObj.column_number_data == 'function' or typeof columnObj.column_number_render == 'function'
          dataRenderFunc = true
        if rowData? and dataRenderFunc != true
          if columnObj.column_number_data?
            column_number_filter = columnObj.column_number_data
            val = dot2obj(rowData, column_number_filter)
          else
            val = rowData[column_number_filter]
        else
          val = aData[column_number_filter]
        column_data_type = columnObj.column_data_type
        html_data_type = columnObj.html_data_type
        if column_data_type == 'html' or column_data_type == 'rendered_html'
          if html_data_type == undefined
            html_data_type = 'text'
          if $(val).length != 0
            switch html_data_type
              when 'text'
                val = $(val).text()
              when 'value'
                val = $(val).val()
              when 'id'
                val = val.id
              when 'selector'
                val = $(val).find(columnObj.html_data_selector).text()
        else
          if typeof val == 'object'
            if columnObj.html5_data?
              val = val['@' + columnObj.html5_data]
        #omit empty rows when filtering
        if val == '' and (min != '' or max != '')
          return false
        try
          if min.length == date_format.length + 2 or columnObj.datepicker_type == 'bootstrap-datetimepicker'
            if columnObj.datepicker_type == 'jquery-ui'
              min = if min != '' then $.datepicker.parseDate(date_format, min) else min
            else if columnObj.datepicker_type == 'bootstrap-datetimepicker'
              min = if min != '' then moment(min, date_format).toDate() else min
        catch err1
        try
          if max.length == date_format.length + 2 or columnObj.datepicker_type == 'bootstrap-datetimepicker'
            if columnObj.datepicker_type == 'jquery-ui'
              max = if max != '' then $.datepicker.parseDate(date_format, max) else max
            else if columnObj.datepicker_type == 'bootstrap-datetimepicker'
              max = if max != '' then moment(max, date_format).toDate() else max
        catch err2
        try
          if columnObj.datepicker_type == 'jquery-ui'
            val = if val != '' then $.datepicker.parseDate(date_format, val) else val
          else if columnObj.datepicker_type == 'bootstrap-datetimepicker'
            val = if val != '' then moment(val, date_format).toDate() else val
        catch err3
        if date_format.toLowerCase() != 'hh:mm'
          if (min == '' or !(min instanceof Date)) and (max == '' or !(max instanceof Date))
            retVal = true
          else if min == '' and val <= max
            retVal = true
          else if min <= val and '' == max
            retVal = true
          else if min <= val and val <= max
            retVal = true
        else
          min_time = moment(min)
          min_time = min_time.minutes() + min_time.hours() * 60
          if isNaN(min_time)
            min_time = ''
          max_time = moment(max)
          max_time = max_time.minutes() + max_time.hours() * 60
          if isNaN(max_time)
            max_time = ''
          val = moment(val)
          val = val.minutes() + val.hours() * 60
          if (min == '' or !moment(min, date_format).isValid()) and (max == '' or !moment(max, date_format).isValid())
            retVal = true
          else if min_time == '' and val <= max_time
            retVal = true
          else if min_time <= val and '' == max_time
            retVal = true
          else if min_time <= val and val <= max_time
            retVal = true
        retVal
      return

    addRangeNumberFilter = (filter_selector_string, table_selector_jq_friendly, column_number, filter_reset_button_text, filter_default_label, ignore_char) ->
      fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-from-' + column_number
      toId = 'yadcf-filter-' + table_selector_jq_friendly + '-to-' + column_number
      filter_selector_string_tmp = undefined
      filter_wrapper_id = undefined
      oTable = undefined
      columnObj = undefined
      filterActionStr = undefined
      filter_wrapper_id = 'yadcf-filter-wrapper-' + table_selector_jq_friendly + '-' + column_number
      if $('#' + filter_wrapper_id).length > 0
        return
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      columnObj = getOptions(oTable.selector)[column_number]
      # add a wrapper to hold both filter and reset button
      $(filter_selector_string).append '<div onmousedown="yadcf.stopPropagation(event);" onclick="yadcf.stopPropagation(event);"  id="' + filter_wrapper_id + '" class="yadcf-filter-wrapper"></div>'
      filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper'
      filter_selector_string_tmp = filter_selector_string
      $(filter_selector_string).append '<div id="yadcf-filter-wrapper-inner-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter-wrapper-inner"></div>'
      filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper-inner'
      filterActionStr = 'onkeyup="yadcf.rangeNumberKeyUP(\'' + table_selector_jq_friendly + '\',event);"'
      if columnObj.externally_triggered == true
        filterActionStr = ''
      $(filter_selector_string).append '<input onkeydown="yadcf.preventDefaultForEnter(event);" placeholder="' + filter_default_label[0] + '" id="' + fromId + '" class="yadcf-filter-range-number yadcf-filter-range-start yadcf-filter-range" ' + filterActionStr + '></input>'
      $(filter_selector_string).append '<span class="yadcf-filter-range-number-seperator" >' + '</span>'
      $(filter_selector_string).append '<input onkeydown="yadcf.preventDefaultForEnter(event);" placeholder="' + filter_default_label[1] + '" id="' + toId + '" class="yadcf-filter-range-number yadcf-filter-range-end yadcf-filter-range" ' + filterActionStr + '></input>'
      if filter_reset_button_text != false
        $(filter_selector_string_tmp).append '<button type="button" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.rangeClear(\'' + table_selector_jq_friendly + '\',event,' + column_number + '); return false;" class="yadcf-filter-reset-button">' + filter_reset_button_text + '</button>'
      if oTable.fnSettings().oFeatures.bStateSave == true and oTable.fnSettings().oLoadedState
        if oTable.fnSettings().oLoadedState.yadcfState and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly] and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number]
          $('#' + fromId).val oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].from
          if oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].from != ''
            $('#' + fromId).addClass 'inuse'
          $('#' + toId).val oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].to
          if oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].to != ''
            $('#' + toId).addClass 'inuse'
      resetIApiIndex()
      if oTable.fnSettings().oFeatures.bServerSide != true
        addRangeNumberAndSliderFilterCapability table_selector_jq_friendly, fromId, toId, column_number, ignore_char
      return

    dateSelectSingle = (pDate, pEvent, clear) ->
      oTable = undefined
      date = undefined
      event = undefined
      column_number = undefined
      dashIndex = undefined
      table_selector_jq_friendly = undefined
      date_str = undefined
      column_number_filter = undefined
      settingsDt = undefined
      columnObj = undefined
      if pDate.type == 'dp'
        event = pDate.target
      else
        date = pDate
        event = pEvent
      column_number = $(event).attr('id').replace('yadcf-filter-', '').replace('-date', '').replace('-reset', '')
      dashIndex = column_number.lastIndexOf('-')
      table_selector_jq_friendly = column_number.substring(0, dashIndex)
      column_number = column_number.substring(dashIndex + 1)
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      settingsDt = getSettingsObjFromTable(oTable)
      columnObj = getOptions(oTable.selector)[column_number]
      if pDate.type == 'dp'
        if moment($(event).val(), columnObj.date_format).isValid()
          date = $(event).val()
        else
          clear = 'clear'
        $(event).blur()
      column_number_filter = calcColumnNumberFilter(settingsDt, column_number, table_selector_jq_friendly)
      if clear == undefined
        oTable.fnFilter date, column_number_filter
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).addClass 'inuse'
      else if clear == 'clear'
        if exGetColumnFilterVal(oTable, column_number) == ''
          return
        oTable.fnFilter '', column_number_filter
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val('').removeClass 'inuse'
      resetIApiIndex()
      return

    dateSelect = (pDate, pEvent) ->
      oTable = undefined
      column_number = undefined
      dashIndex = undefined
      table_selector_jq_friendly = undefined
      yadcfState = undefined
      from = undefined
      to = undefined
      date = undefined
      event = undefined
      columnObj = undefined
      if pDate.type == 'dp'
        event = pDate.target
      else
        date = pDate
        event = pEvent
      column_number = $(event).attr('id').replace('yadcf-filter-', '').replace('-from-date', '').replace('-to-date', '')
      dashIndex = column_number.lastIndexOf('-')
      table_selector_jq_friendly = column_number.substring(0, dashIndex)
      column_number = column_number.substring(dashIndex + 1)
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      columnObj = getOptions(oTable.selector)[column_number]
      if pDate.type == 'dp'
        event = pDate.target
        if pDate.date == false or !moment($(event).val(), columnObj.date_format).isValid()
          $(event).removeClass 'inuse'
          $(event).data('DateTimePicker').minDate false
        else
          $(event).addClass 'inuse'
        $(event).blur()
      else
        $(event).addClass 'inuse'
      if $(event).attr('id').indexOf('-from-') != -1
        from = document.getElementById($(event).attr('id')).value
        to = document.getElementById($(event).attr('id').replace('-from-', '-to-')).value
      else
        to = document.getElementById($(event).attr('id')).value
        from = document.getElementById($(event).attr('id').replace('-to-', '-from-')).value
      if oTable.fnSettings().oFeatures.bServerSide != true
        oTable.fnDraw()
      else
        oTable.fnFilter from + '-yadcf_delim-' + to, column_number
      if !oTable.fnSettings().oLoadedState
        oTable.fnSettings().oLoadedState = {}
        oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
      if oTable.fnSettings().oFeatures.bStateSave == true
        if oTable.fnSettings().oLoadedState.yadcfState? and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly]?
          oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number] =
            'from': from
            'to': to
        else
          yadcfState = {}
          yadcfState[table_selector_jq_friendly] = []
          yadcfState[table_selector_jq_friendly][column_number] =
            'from': from
            'to': to
          oTable.fnSettings().oLoadedState.yadcfState = yadcfState
        oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
      resetIApiIndex()
      return

    addRangeDateFilter = (filter_selector_string, table_selector_jq_friendly, column_number, filter_reset_button_text, filter_default_label, date_format) ->
      fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-from-date-' + column_number
      toId = 'yadcf-filter-' + table_selector_jq_friendly + '-to-date-' + column_number
      filter_selector_string_tmp = undefined
      filter_wrapper_id = undefined
      oTable = undefined
      columnObj = undefined
      datepickerObj = {}
      filterActionStr = undefined
      filterClass = ''
      $fromInput = undefined
      $toInput = undefined
      innerWrapperAdditionalClass = ''
      filter_wrapper_id = 'yadcf-filter-wrapper-' + table_selector_jq_friendly + '-' + column_number
      if $('#' + filter_wrapper_id).length > 0
        return
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      columnObj = getOptions(oTable.selector)[column_number]
      if columnObj.datepicker_type == 'bootstrap-datepicker'
        innerWrapperAdditionalClass = 'input-daterange'
      # add a wrapper to hold both filter and reset button
      $(filter_selector_string).append '<div onmousedown="yadcf.stopPropagation(event);" onclick="yadcf.stopPropagation(event);"  id="' + filter_wrapper_id + '" class="yadcf-filter-wrapper"></div>'
      filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper'
      filter_selector_string_tmp = filter_selector_string
      $(filter_selector_string).append '<div id="yadcf-filter-wrapper-inner-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter-wrapper-inner ' + innerWrapperAdditionalClass + '"></div>'
      filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper-inner'
      filterActionStr = 'onkeyup="yadcf.rangeDateKeyUP(\'' + table_selector_jq_friendly + '\',\'' + date_format + '\',event);"'
      if columnObj.externally_triggered == true
        filterActionStr = ''
      $(filter_selector_string).append '<input onkeydown="yadcf.preventDefaultForEnter(event);" placeholder="' + filter_default_label[0] + '" id="' + fromId + '" class="yadcf-filter-range-date yadcf-filter-range-start yadcf-filter-range" ' + filterActionStr + '></input>'
      $(filter_selector_string).append '<span class="yadcf-filter-range-date-seperator" >' + '</span>'
      $(filter_selector_string).append '<input onkeydown="yadcf.preventDefaultForEnter(event);" placeholder="' + filter_default_label[1] + '" id="' + toId + '" class="yadcf-filter-range-date yadcf-filter-range-end yadcf-filter-range" ' + filterActionStr + '></input>'
      $fromInput = $('#' + fromId)
      $toInput = $('#' + toId)
      if filter_reset_button_text != false
        $(filter_selector_string_tmp).append '<button type="button" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.rangeClear(\'' + table_selector_jq_friendly + '\',event,' + column_number + '); return false;" class="yadcf-filter-reset-button">' + filter_reset_button_text + '</button>'
      if columnObj.datepicker_type == 'jquery-ui'
        datepickerObj.dateFormat = date_format
      else if columnObj.datepicker_type == 'bootstrap-datetimepicker'
        datepickerObj.format = date_format
      if columnObj.externally_triggered != true
        if columnObj.datepicker_type == 'jquery-ui'
          datepickerObj.onSelect = dateSelect
      datepickerObj = $.extend({}, datepickerObj, columnObj.filter_plugin_options)
      if columnObj.datepicker_type == 'jquery-ui'
        $fromInput.datepicker $.extend(datepickerObj, onClose: (selectedDate) ->
          $toInput.datepicker 'option', 'minDate', selectedDate
          return
        )
        $toInput.datepicker $.extend(datepickerObj, onClose: (selectedDate) ->
          $fromInput.datepicker 'option', 'maxDate', selectedDate
          return
        )
      else if columnObj.datepicker_type == 'bootstrap-datetimepicker'
        datepickerObj.useCurrent = false
        $fromInput.datetimepicker datepickerObj
        $toInput.datetimepicker datepickerObj
        if datepickerObj.format.toLowerCase() != 'hh:mm'
          $fromInput.on 'dp.change', (e) ->
            $toInput.data('DateTimePicker').minDate e.date
            return
          $toInput.on 'dp.change', (e) ->
            $fromInput.data('DateTimePicker').maxDate e.date
            return
          if columnObj.externally_triggered != true
            $fromInput.add($toInput).on 'dp.change', dateSelect
        else
          if columnObj.externally_triggered != true
            $fromInput.add($toInput).on 'dp.hide', dateSelect
      if oTable.fnSettings().oFeatures.bStateSave == true and oTable.fnSettings().oLoadedState
        if oTable.fnSettings().oLoadedState.yadcfState and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly] and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number]
          $('#' + fromId).val oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].from
          if oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].from != ''
            $('#' + fromId).addClass 'inuse'
          $('#' + toId).val oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].to
          if oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].to != ''
            $('#' + toId).addClass 'inuse'
      if oTable.fnSettings().oFeatures.bServerSide != true
        addRangeDateFilterCapability table_selector_jq_friendly, fromId, toId, column_number, date_format
      resetIApiIndex()
      return

    addDateFilter = (filter_selector_string, table_selector_jq_friendly, column_number, filter_reset_button_text, filter_default_label, date_format) ->
      dateId = 'yadcf-filter-' + table_selector_jq_friendly + '-' + column_number
      filter_selector_string_tmp = undefined
      filter_wrapper_id = undefined
      oTable = undefined
      columnObj = undefined
      datepickerObj = {}
      filterActionStr = undefined
      filter_wrapper_id = 'yadcf-filter-wrapper-' + table_selector_jq_friendly + '-' + column_number
      if $('#' + filter_wrapper_id).length > 0
        return
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      columnObj = getOptions(oTable.selector)[column_number]
      #add a wrapper to hold both filter and reset button
      $(filter_selector_string).append '<div onmousedown="yadcf.stopPropagation(event);" onclick="yadcf.stopPropagation(event);"  id="' + filter_wrapper_id + '" class="yadcf-filter-wrapper"></div>'
      filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper'
      filter_selector_string_tmp = filter_selector_string
      filterActionStr = 'onkeyup="yadcf.dateKeyUP(\'' + table_selector_jq_friendly + '\',\'' + date_format + '\',event);"'
      if columnObj.externally_triggered == true
        filterActionStr = ''
      $(filter_selector_string).append '<input onkeydown="yadcf.preventDefaultForEnter(event);" placeholder="' + filter_default_label + '" id="' + dateId + '" class="yadcf-filter-date" ' + filterActionStr + '></input>'
      if filter_reset_button_text != false
        $(filter_selector_string_tmp).append '<button type="button" id="' + dateId + '-reset" ' + 'onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.dateSelectSingle(\'' + table_selector_jq_friendly + '\',yadcf.eventTargetFixUp(event).target, \'clear\'); return false;" class="yadcf-filter-reset-button">' + filter_reset_button_text + '</button>'
      if columnObj.datepicker_type == 'jquery-ui'
        datepickerObj.dateFormat = date_format
      else if columnObj.datepicker_type == 'bootstrap-datetimepicker'
        datepickerObj.format = date_format
      if columnObj.externally_triggered != true
        if columnObj.datepicker_type == 'jquery-ui'
          datepickerObj.onSelect = dateSelectSingle
      datepickerObj = $.extend({}, datepickerObj, columnObj.filter_plugin_options)
      if columnObj.datepicker_type == 'jquery-ui'
        $('#' + dateId).datepicker datepickerObj
      else if columnObj.datepicker_type == 'bootstrap-datetimepicker'
        datepickerObj.useCurrent = false
        $('#' + dateId).datetimepicker datepickerObj
        if columnObj.externally_triggered != true
          if datepickerObj.format.toLowerCase() != 'hh:mm'
            $('#' + dateId).on 'dp.change', dateSelectSingle
          else
            $('#' + dateId).on 'dp.hide', dateSelectSingle
      else if columnObj.datepicker_type == 'bootstrap-datepicker'
        $('#' + dateId).datepicker {}
      if oTable.fnSettings().aoPreSearchCols[column_number].sSearch != ''
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val(oTable.fnSettings().aoPreSearchCols[column_number].sSearch).addClass 'inuse'
      resetIApiIndex()
      return

    rangeNumberSldierDrawTips = (min_tip_val, max_tip_val, min_tip_id, max_tip_id, table_selector_jq_friendly, column_number) ->
      first_handle = $('#yadcf-filter-wrapper-inner-' + table_selector_jq_friendly + '-' + column_number + ' .ui-slider-handle:first')
      last_handle = $('#yadcf-filter-wrapper-inner-' + table_selector_jq_friendly + '-' + column_number + ' .ui-slider-handle:last')
      min_tip_inner = undefined
      max_tip_inner = undefined
      min_tip_inner = '<div id="' + min_tip_id + '" class="yadcf-filter-range-number-slider-min-tip-inner">' + min_tip_val + '</div>'
      max_tip_inner = '<div id="' + max_tip_id + '" class="yadcf-filter-range-number-slider-max-tip-inner">' + max_tip_val + '</div>'
      $(first_handle).addClass('yadcf-filter-range-number-slider-min-tip').html min_tip_inner
      $(last_handle).addClass('yadcf-filter-range-number-slider-max-tip').html max_tip_inner
      return

    rangeNumberSliderChange = (table_selector_jq_friendly, event, ui) ->
      event = eventTargetFixUp(event)
      oTable = undefined
      min_val = undefined
      max_val = undefined
      slider_inuse = undefined
      yadcfState = undefined
      column_number = $(event.target).attr('id').replace('yadcf-filter-', '').replace(table_selector_jq_friendly, '').replace('-slider-', '')
      columnObj = undefined
      keyUp = undefined
      oTable = oTables[table_selector_jq_friendly]
      columnObj = getOptions(oTable.selector)[column_number]

      keyUp = ->
        $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
        if oTable.fnSettings().oFeatures.bServerSide != true
          oTable.fnDraw()
        else
          oTable.fnFilter ui.values[0] + '-yadcf_delim-' + ui.values[1], column_number
        min_val = +$($(event.target).parent().find('.yadcf-filter-range-number-slider-min-tip-hidden')).text()
        max_val = +$($(event.target).parent().find('.yadcf-filter-range-number-slider-max-tip-hidden')).text()
        if min_val != ui.values[0]
          $($(event.target).find('.ui-slider-handle')[0]).addClass 'inuse'
          slider_inuse = true
        else
          $($(event.target).find('.ui-slider-handle')[0]).removeClass 'inuse'
        if max_val != ui.values[1]
          $($(event.target).find('.ui-slider-handle')[1]).addClass 'inuse'
          slider_inuse = true
        else
          $($(event.target).find('.ui-slider-handle')[1]).removeClass 'inuse'
        if slider_inuse == true
          $(event.target).find('.ui-slider-range').addClass 'inuse'
        else
          $(event.target).find('.ui-slider-range').removeClass 'inuse'
        if !oTable.fnSettings().oLoadedState
          oTable.fnSettings().oLoadedState = {}
          oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
        if oTable.fnSettings().oFeatures.bStateSave == true
          if oTable.fnSettings().oLoadedState.yadcfState? and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly]?
            oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number] =
              'from': ui.values[0]
              'to': ui.values[1]
          else
            yadcfState = {}
            yadcfState[table_selector_jq_friendly] = []
            yadcfState[table_selector_jq_friendly][column_number] =
              'from': ui.values[0]
              'to': ui.values[1]
            oTable.fnSettings().oLoadedState.yadcfState = yadcfState
          oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
        resetIApiIndex()
        return

      if columnObj.filter_delay == undefined
        keyUp()
      else
        yadcfDelay (->
          keyUp()
          return
        ), columnObj.filter_delay
      return

    addRangeNumberSliderFilter = (filter_selector_string, table_selector_jq_friendly, column_number, filter_reset_button_text, min_val, max_val, ignore_char) ->
      sliderId = 'yadcf-filter-' + table_selector_jq_friendly + '-slider-' + column_number
      min_tip_id = 'yadcf-filter-' + table_selector_jq_friendly + '-min_tip-' + column_number
      max_tip_id = 'yadcf-filter-' + table_selector_jq_friendly + '-max_tip-' + column_number
      filter_selector_string_tmp = undefined
      filter_wrapper_id = undefined
      oTable = undefined
      min_state_val = min_val
      max_state_val = max_val
      columnObj = undefined
      slideFunc = undefined
      changeFunc = undefined
      sliderObj = undefined
      sliderMaxMin =
        min: min_val
        max: max_val
      filter_wrapper_id = 'yadcf-filter-wrapper-' + table_selector_jq_friendly + '-' + column_number
      if $('#' + filter_wrapper_id).length > 0
        return
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      columnObj = getOptions(oTable.selector)[column_number]
      if oTable.fnSettings().oFeatures.bStateSave == true and oTable.fnSettings().oLoadedState
        if oTable.fnSettings().oLoadedState.yadcfState and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly] and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number]
          if min_val != oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].from
            min_state_val = oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].from
          if max_val != oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].to
            max_state_val = oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].to
      # add a wrapper to hold both filter and reset button
      if isFinite(min_val) and isFinite(max_val) and isFinite(min_state_val) and isFinite(max_state_val)
        $(filter_selector_string).append '<div onmousedown="yadcf.stopPropagation(event);" onclick="yadcf.stopPropagation(event);"  id="' + filter_wrapper_id + '" class="yadcf-filter-wrapper"></div>'
        filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper'
        filter_selector_string_tmp = filter_selector_string
        $(filter_selector_string).append '<div id="yadcf-filter-wrapper-inner-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-number-slider-filter-wrapper-inner"></div>'
        filter_selector_string = filter_selector_string + ' div.yadcf-number-slider-filter-wrapper-inner'
        $(filter_selector_string).append '<div id="' + sliderId + '" class="yadcf-filter-range-number-slider"></div>'
        filter_selector_string = filter_selector_string + ' #' + sliderId
        $(filter_selector_string).append '<span class="yadcf-filter-range-number-slider-min-tip-hidden hide">' + min_val + '</span>'
        $(filter_selector_string).append '<span class="yadcf-filter-range-number-slider-max-tip-hidden hide">' + max_val + '</span>'
        if columnObj.externally_triggered != true

          slideFunc = (event, ui) ->
            rangeNumberSldierDrawTips ui.values[0], ui.values[1], min_tip_id, max_tip_id, table_selector_jq_friendly, column_number
            rangeNumberSliderChange table_selector_jq_friendly, event, ui
            return

          changeFunc = (event, ui) ->
            rangeNumberSldierDrawTips ui.values[0], ui.values[1], min_tip_id, max_tip_id, table_selector_jq_friendly, column_number
            if event.originalEvent or $(event.target).slider('option', 'yadcf-reset') == true
              $(event.target).slider 'option', 'yadcf-reset', false
              rangeNumberSliderChange table_selector_jq_friendly, event, ui
            return

        else

          slideFunc = (event, ui) ->
            rangeNumberSldierDrawTips ui.values[0], ui.values[1], min_tip_id, max_tip_id, table_selector_jq_friendly, column_number
            return

          changeFunc = (event, ui) ->
            rangeNumberSldierDrawTips ui.values[0], ui.values[1], min_tip_id, max_tip_id, table_selector_jq_friendly, column_number
            return

        sliderObj =
          range: true
          min: min_val
          max: max_val
          values: [
            min_state_val
            max_state_val
          ]
          create: (event, ui) ->
            rangeNumberSldierDrawTips min_state_val, max_state_val, min_tip_id, max_tip_id, table_selector_jq_friendly, column_number
            return
          slide: slideFunc
          change: changeFunc
        if columnObj.filter_plugin_options?
          $.extend sliderObj, columnObj.filter_plugin_options
        $('#' + sliderId).slider sliderObj
        if filter_reset_button_text != false
          $(filter_selector_string_tmp).append '<button type="button" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.rangeNumberSliderClear(\'' + table_selector_jq_friendly + '\',event); return false;" class="yadcf-filter-reset-button range-number-slider-reset-button">' + filter_reset_button_text + '</button>'
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      if oTable.fnSettings().oFeatures.bStateSave == true and oTable.fnSettings().oLoadedState
        if oTable.fnSettings().oLoadedState.yadcfState and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly] and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number]
          if isFinite(min_val) and min_val != oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].from
            $($(filter_selector_string).find('.ui-slider-handle')[0]).addClass 'inuse'
          if isFinite(max_val) and max_val != oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].to
            $($(filter_selector_string).find('.ui-slider-handle')[1]).addClass 'inuse'
          if isFinite(min_val) and isFinite(max_val) and (min_val != oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].from or max_val != oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number].to)
            $($(filter_selector_string).find('.ui-slider-range')).addClass 'inuse'
      resetIApiIndex()
      if oTable.fnSettings().oFeatures.bServerSide != true
        addRangeNumberAndSliderFilterCapability table_selector_jq_friendly, min_tip_id, max_tip_id, column_number, ignore_char, sliderMaxMin
      return

    destroyThirdPartyPlugins = (table_arg) ->
      tableOptions = undefined
      table_selector_jq_friendly = undefined
      settingsDt = undefined
      column_number = undefined
      optionsObj = undefined
      fromId = undefined
      toId = undefined
      # check if the table arg is from new datatables API (capital "D")
      if table_arg.settings?
        table_arg = table_arg.settings()[0].oInstance
      tableOptions = getOptions(table_arg.selector)
      table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendly(table_arg.selector)
      settingsDt = getSettingsObjFromTable(table_arg)
      for columnObjKey of tableOptions
        if tableOptions.hasOwnProperty(columnObjKey)
          optionsObj = tableOptions[columnObjKey]
          column_number = optionsObj.column_number
          switch optionsObj.filter_type
            when 'multi_select', 'multi_select_custom_func', 'select', 'custom_func'
              switch optionsObj.select_type
                when 'chosen'
                  $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).chosen 'destroy'
                when 'select2'
                  $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).select2 'destroy'
                when 'custom_select'
                  if selectElementCustomDestroyFunc?
                    selectElementCustomDestroyFunc $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number)
            when 'auto_complete'
              $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).autocomplete 'destroy'
            when 'date'
              switch optionsObj.select_type
                when 'jquery-ui'
                  $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).datepicker 'destroy'
                when 'bootstrap-datetimepicker'
                  $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).destroy()
            when 'range_date'
              fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-from-date-' + column_number
              toId = 'yadcf-filter-' + table_selector_jq_friendly + '-to-date-' + column_number
              switch optionsObj.select_type
                when 'jquery-ui'
                  $('#' + fromId).datepicker 'destroy'
                  $('#' + toId).datepicker 'destroy'
                when 'bootstrap-datetimepicker'
                  $('#' + fromId).destroy()
                  $('#' + toId).destroy()
            when 'range_number_slider'
              $('#yadcf-filter-' + table_selector_jq_friendly + '-slider-' + column_number).slider 'destroy'
      return

    removeFilters = (oTable, args, table_selector) ->
      $('.yadcf-filter-wrapper').remove()
      if yadcfVersionCheck('1.10')
        $(document).off 'draw.dt', oTable.selector
        $(document).off 'xhr.dt', oTable.selector
        $(document).off 'column-visibility.dt', oTable.selector
        $(document).off 'destroy.dt', oTable.selector
      else
        $(document).off 'draw', oTable.selector
        $(document).off 'destroy', oTable.selector
      destroyThirdPartyPlugins oTable
      return

    sortAlphaNum = (a, b) ->
      aA = a.replace(reA, '')
      bA = b.replace(reA, '')
      aN = undefined
      bN = undefined
      if aA == bA
        aN = parseInt(a.replace(reN, ''), 10)
        bN = parseInt(b.replace(reN, ''), 10)
        return if aN == bN then 0 else if aN > bN then 1 else -1
      if aA > bA then 1 else -1

    sortColumnData = (column_data, columnObj) ->
      numArray = []
      alphaArray = []
      if columnObj.filter_type == 'select' or columnObj.filter_type == 'auto_complete' or columnObj.filter_type == 'multi_select' or columnObj.filter_type == 'multi_select_custom_func' or columnObj.filter_type == 'custom_func'
        if columnObj.sort_as == 'alpha'
          if columnObj.sort_order == 'asc'
            column_data.sort()
          else if columnObj.sort_order == 'desc'
            column_data.sort()
            column_data.reverse()
        else if columnObj.sort_as == 'num'
          if columnObj.sort_order == 'asc'
            column_data.sort sortNumAsc
          else if columnObj.sort_order == 'desc'
            column_data.sort sortNumDesc
        else if columnObj.sort_as == 'alphaNum'
          if columnObj.sort_order == 'asc'
            column_data.sort sortAlphaNum
          else if columnObj.sort_order == 'desc'
            column_data.sort sortAlphaNum
            column_data.reverse()
        else if columnObj.sort_as == 'custom'
          column_data.sort columnObj.sort_as_custom_func
      column_data

    getFilteredRows = (table) ->
      dataTmp = undefined
      data = []
      i = undefined
      if yadcfVersionCheck('1.10')
        dataTmp = table._('tr', filter: 'applied')
      else
        dataTmp = table.rows(filter: 'applied').data().toArray()
      i = 0
      while i < dataTmp.length
        data.push _aData: dataTmp[i]
        i++
      data

    parseTableColumn = (pTable, columnObj, table_selector_jq_friendly) ->
      col_inner_elements = undefined
      col_inner_data = undefined
      j = undefined
      k = undefined
      col_filter_array = {}
      column_data = []
      data = undefined
      data_length = undefined
      settingsDt = undefined
      column_number_filter = undefined
      settingsDt = getSettingsObjFromTable(pTable)
      if columnObj.cumulative_filtering != true
        data = settingsDt.aoData
        data_length = data.length
      else
        data = getFilteredRows(pTable)
        data_length = data.length
      if columnObj.col_filter_array?
        col_filter_array = columnObj.col_filter_array
      column_number_filter = calcColumnNumberFilter(settingsDt, columnObj.column_number, table_selector_jq_friendly)
      if isNaN(settingsDt.aoColumns[column_number_filter].mData) and typeof settingsDt.aoColumns[column_number_filter].mData != 'object'
        columnObj.column_number_data = settingsDt.aoColumns[column_number_filter].mData
      if isNaN(settingsDt.aoColumns[column_number_filter].mRender) and typeof settingsDt.aoColumns[column_number_filter].mRender != 'object'
        columnObj.column_number_render = settingsDt.aoColumns[column_number_filter].mRender
      j = 0
      while j < data_length
        if columnObj.column_data_type == 'html'
          if columnObj.column_number_data == undefined
            col_inner_elements = $(data[j]._aData[column_number_filter])
          else
            col_inner_elements = dot2obj(data[j]._aData, columnObj.column_number_data)
            col_inner_elements = $(col_inner_elements)
          if col_inner_elements.length > 0
            k = 0
            while k < col_inner_elements.length
              switch columnObj.html_data_type
                when 'text'
                  col_inner_data = $(col_inner_elements[k]).text()
                when 'value'
                  col_inner_data = $(col_inner_elements[k]).val()
                when 'id'
                  col_inner_data = col_inner_elements[k].id
                when 'selector'
                  col_inner_data = $(col_inner_elements[k]).find(columnObj.html_data_selector).text()
              if $.trim(col_inner_data) != '' and !col_filter_array.hasOwnProperty(col_inner_data)
                col_filter_array[col_inner_data] = col_inner_data
                column_data.push col_inner_data
              k++
          else
            col_inner_data = col_inner_elements.selector
            if $.trim(col_inner_data) != '' and !col_filter_array.hasOwnProperty(col_inner_data)
              col_filter_array[col_inner_data] = col_inner_data
              column_data.push col_inner_data
        else if columnObj.column_data_type == 'text'
          if columnObj.text_data_delimiter?
            if columnObj.column_number_data == undefined
              col_inner_elements = data[j]._aData[column_number_filter].split(columnObj.text_data_delimiter)
            else
              col_inner_elements = dot2obj(data[j]._aData, columnObj.column_number_data)
              col_inner_elements = (col_inner_elements + '').split(columnObj.text_data_delimiter)
            k = 0
            while k < col_inner_elements.length
              col_inner_data = col_inner_elements[k]
              if $.trim(col_inner_data) != '' and !col_filter_array.hasOwnProperty(col_inner_data)
                col_filter_array[col_inner_data] = col_inner_data
                column_data.push col_inner_data
              k++
          else
            if columnObj.column_number_data == undefined
              col_inner_data = data[j]._aData[column_number_filter]
              if typeof col_inner_data == 'object'
                if columnObj.html5_data?
                  col_inner_data = col_inner_data['@' + columnObj.html5_data]
                else
                  console.log 'Warning: Looks like you have forgot to define the html5_data attribute for the ' + columnObj.column_number + ' column'
                  return
            else if data[j]._aFilterData? and data[j]._aFilterData?
              col_inner_data = data[j]._aFilterData[column_number_filter]
            else
              col_inner_data = dot2obj(data[j]._aData, columnObj.column_number_data)
            if $.trim(col_inner_data) != '' and !col_filter_array.hasOwnProperty(col_inner_data)
              col_filter_array[col_inner_data] = col_inner_data
              column_data.push col_inner_data
        else if columnObj.column_data_type == 'rendered_html'
          col_inner_elements = data[j]._aFilterData[column_number_filter]
          col_inner_elements = $(col_inner_elements)
          if col_inner_elements.length > 0
            k = 0
            while k < col_inner_elements.length
              switch columnObj.html_data_type
                when 'text'
                  col_inner_data = $(col_inner_elements[k]).text()
                when 'value'
                  col_inner_data = $(col_inner_elements[k]).val()
                when 'id'
                  col_inner_data = col_inner_elements[k].id
                when 'selector'
                  col_inner_data = $(col_inner_elements[k]).find(columnObj.html_data_selector).text()
              k++
          else
            col_inner_data = col_inner_elements.selector
          if $.trim(col_inner_data) != '' and !col_filter_array.hasOwnProperty(col_inner_data)
            col_filter_array[col_inner_data] = col_inner_data
            column_data.push col_inner_data
        j++
      columnObj.col_filter_array = col_filter_array
      column_data

    appendFilters = (oTable, args, table_selector) ->
      i = 0
      $filter_selector = undefined
      filter_selector_string = undefined
      data = undefined
      filter_container_id = undefined
      column_number_data = undefined
      column_number = undefined
      column_position = undefined
      column_data_type = undefined
      html_data_type = undefined
      text_data_delimiter = undefined
      filter_default_label = undefined
      filter_reset_button_text = undefined
      enable_auto_complete = undefined
      sort_as = undefined
      sort_order = undefined
      date_format = undefined
      ignore_char = undefined
      filter_match_mode = undefined
      column_data = undefined
      column_data_temp = undefined
      options_tmp = undefined
      j = undefined
      k = undefined
      data_length = undefined
      col_inner_elements = undefined
      col_inner_data = undefined
      ii = undefined
      table_selector_jq_friendly = undefined
      min_val = undefined
      max_val = undefined
      col_num_visible = undefined
      col_num_visible_iter = undefined
      tmpStr = undefined
      columnObj = undefined
      filters_position = undefined
      unique_th = undefined
      settingsDt = undefined
      filterActionStr = undefined
      custom_func_filter_value_holder = undefined
      exclude_str = undefined
      tableDT = undefined
      columnFilterVal = undefined
      settingsDt = getSettingsObjFromTable(oTable)
      table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendly(table_selector)
      tableDT = tablesDT[table_selector_jq_friendly]
      initColReorder2 settingsDt, table_selector_jq_friendly
      filters_position = $(document).data(table_selector + '_filters_position')
      if settingsDt.oScroll.sX != '' or settingsDt.oScroll.sY != ''
        table_selector = '.yadcf-datatables-table-' + table_selector_jq_friendly
      if oTable._fnGetUniqueThs()?
        unique_th = oTable._fnGetUniqueThs()
      for columnObjKey of args
        if args.hasOwnProperty(columnObjKey)
          columnObj = args[columnObjKey]
          options_tmp = ''
          tmpStr = ''
          data = columnObj.data
          column_data = []
          column_data_temp = []
          filter_container_id = columnObj.filter_container_id
          column_number = columnObj.column_number
          column_number = +column_number
          column_position = column_number
          if plugins[table_selector_jq_friendly]? and plugins[table_selector_jq_friendly]? and plugins[table_selector_jq_friendly].ColReorder?
            column_position = plugins[table_selector_jq_friendly].ColReorder[column_number]
          columnObj.column_number = column_number
          column_number_data = undefined
          if isNaN(settingsDt.aoColumns[column_position].mData) and typeof settingsDt.aoColumns[column_position].mData != 'object'
            column_number_data = settingsDt.aoColumns[column_position].mData
            columnObj.column_number_data = column_number_data
          if isNaN(settingsDt.aoColumns[column_position].mRender) and typeof settingsDt.aoColumns[column_position].mRender != 'object'
            columnObj.column_number_render = settingsDt.aoColumns[column_position].mRender
          column_data_type = columnObj.column_data_type
          html_data_type = columnObj.html_data_type
          text_data_delimiter = columnObj.text_data_delimiter
          filter_default_label = columnObj.filter_default_label
          filter_reset_button_text = columnObj.filter_reset_button_text
          enable_auto_complete = columnObj.enable_auto_complete
          sort_as = columnObj.sort_as
          sort_order = columnObj.sort_order
          date_format = columnObj.date_format
          # for jquery datepicker
          date_format = date_format.replace('yyyy', 'yy')
          if columnObj.datepicker_type == 'bootstrap-datetimepicker' and columnObj.filter_plugin_options? and columnObj.filter_plugin_options.format?
            date_format = columnObj.filter_plugin_options.format
          columnObj.date_format = date_format
          if columnObj.ignore_char? and !(columnObj.ignore_char instanceof RegExp)
            ignore_char = new RegExp(columnObj.ignore_char, 'g')
            columnObj.ignore_char = ignore_char
          filter_match_mode = columnObj.filter_match_mode
          if column_number == undefined
            alert 'You must specify column number'
            return
          if enable_auto_complete == true
            columnObj.filter_type = 'auto_complete'
          if filter_default_label == undefined
            if columnObj.filter_type == 'select' or columnObj.filter_type == 'custom_func'
              filter_default_label = 'Select value'
            else if columnObj.filter_type == 'multi_select' or columnObj.filter_type == 'multi_select_custom_func'
              filter_default_label = 'Select values'
            else if columnObj.filter_type == 'auto_complete' or columnObj.filter_type == 'text'
              filter_default_label = 'Type to filter'
            else if columnObj.filter_type == 'range_number' or columnObj.filter_type == 'range_date'
              filter_default_label = [
                'from'
                'to'
              ]
            else if columnObj.filter_type == 'date'
              filter_default_label = 'Select a date'
            columnObj.filter_default_label = filter_default_label
          if filter_reset_button_text == undefined
            filter_reset_button_text = 'x'
          if data?
            ii = 0
            while ii < data.length
              column_data.push data[ii]
              ii++
          if data == undefined or columnObj.append_data_to_table_data?
            columnObj.col_filter_array = undefined
            column_data_temp = parseTableColumn(oTable, columnObj, table_selector_jq_friendly)
            if columnObj.append_data_to_table_data != 'before'
              column_data = column_data.concat(column_data_temp)
            else
              column_data_temp = sortColumnData(column_data_temp, columnObj)
              column_data = column_data.concat(column_data_temp)
          if columnObj.append_data_to_table_data == undefined or columnObj.append_data_to_table_data == 'sorted'
            column_data = sortColumnData(column_data, columnObj)
          if columnObj.filter_type == 'range_number_slider'
            min_val = findMinInArray(column_data, columnObj)
            max_val = findMaxInArray(column_data, columnObj)
          if filter_container_id == undefined and columnObj.filter_container_selector == undefined
            #Can't show filter inside a column for a hidden one (place it outside using filter_container_id)
            if settingsDt.aoColumns[column_position].bVisible == false
              ii++
              continue
            if filters_position != 'thead'
              if unique_th == undefined
                #handle hidden columns
                col_num_visible = column_position
                col_num_visible_iter = 0
                while col_num_visible_iter < settingsDt.aoColumns.length and col_num_visible_iter < column_position
                  if settingsDt.aoColumns[col_num_visible_iter].bVisible == false
                    col_num_visible--
                  col_num_visible_iter++
                column_position = col_num_visible
                filter_selector_string = table_selector + ' ' + filters_position + ' th:eq(' + column_position + ')'
              else
                filter_selector_string = table_selector + ' ' + filters_position + ' th:eq(' + $(unique_th[column_position]).index() + ')'
            else
              filter_selector_string = table_selector + ' ' + filters_position + ' tr:eq(' + $(unique_th[column_position]).parent().index() + ') th:eq(' + $(unique_th[column_position]).index() + ')'
            $filter_selector = $(filter_selector_string).find('.yadcf-filter')
          else
            if filter_container_id?
              columnObj.filter_container_selector = '#' + filter_container_id
            if $(columnObj.filter_container_selector).length == 0
              console.log 'ERROR: Filter container could not be found.'
              return
            filter_selector_string = columnObj.filter_container_selector
            $filter_selector = $(filter_selector_string).find('.yadcf-filter')
          if columnObj.filter_type == 'select' or columnObj.filter_type == 'custom_func' or columnObj.filter_type == 'multi_select' or columnObj.filter_type == 'multi_select_custom_func'
            if columnObj.data_as_is != true
              if columnObj.filter_type == 'select' or columnObj.filter_type == 'custom_func'
                options_tmp = '<option value="' + '-1' + '">' + filter_default_label + '</option>'
                if columnObj.select_type == 'select2' and columnObj.select_type_options.placeholder? and columnObj.select_type_options.allowClear == true
                  options_tmp = '<option value=""></option>'
              else if columnObj.filter_type == 'multi_select' or columnObj.filter_type == 'multi_select_custom_func'
                if columnObj.select_type == undefined
                  options_tmp = '<option data-placeholder="true" value="' + '-1' + '">' + filter_default_label + '</option>'
                else
                  options_tmp = ''
              if columnObj.append_data_to_table_data == undefined
                if typeof column_data[0] == 'object'
                  ii = 0
                  while ii < column_data.length
                    options_tmp += '<option value="' + column_data[ii].value + '">' + column_data[ii].label + '</option>'
                    ii++
                else
                  ii = 0
                  while ii < column_data.length
                    options_tmp += '<option value="' + column_data[ii] + '">' + column_data[ii] + '</option>'
                    ii++
              else
                ii = 0
                while ii < column_data.length
                  if typeof column_data[ii] == 'object'
                    options_tmp += '<option value="' + column_data[ii].value + '">' + column_data[ii].label + '</option>'
                  else
                    options_tmp += '<option value="' + column_data[ii] + '">' + column_data[ii] + '</option>'
                  ii++
            else
              options_tmp = columnObj.data
            column_data = options_tmp
          if $filter_selector.length == 1
            if columnObj.filter_type == 'select' or columnObj.filter_type == 'multi_select' or columnObj.filter_type == 'custom_func' or columnObj.filter_type == 'multi_select_custom_func'
              if columnObj.filter_type == 'custom_func' or columnObj.filter_type == 'multi_select_custom_func'
                custom_func_filter_value_holder = $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val()
              $filter_selector.empty()
              $filter_selector.append column_data
              if settingsDt.aoPreSearchCols[column_position].sSearch != ''
                tmpStr = settingsDt.aoPreSearchCols[column_position].sSearch
                if columnObj.filter_type == 'select'
                  tmpStr = yadcfParseMatchFilter(tmpStr, getOptions(oTable.selector)[column_number].filter_match_mode)
                  $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val(tmpStr).addClass 'inuse'
                else if columnObj.filter_type == 'multi_select'
                  tmpStr = yadcfParseMatchFilterMultiSelect(tmpStr, getOptions(oTable.selector)[column_number].filter_match_mode)
                  tmpStr = tmpStr.replace(/\\/g, '')
                  tmpStr = tmpStr.split('|')
                  $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val tmpStr
              if columnObj.filter_type == 'custom_func' or columnObj.filter_type == 'multi_select_custom_func'
                tmpStr = custom_func_filter_value_holder
                if tmpStr == '-1' or tmpStr == undefined
                  $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val tmpStr
                else
                  $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val(tmpStr).addClass 'inuse'
              initializeSelectPlugin columnObj.select_type, $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number), columnObj.select_type_options
            else if columnObj.filter_type == 'auto_complete'
              $(document).data 'yadcf-filter-' + table_selector_jq_friendly + '-' + column_number, column_data
          else
            if filter_container_id == undefined and columnObj.filter_container_selector == undefined
              if $(filter_selector_string + ' div.DataTables_sort_wrapper').length > 0
                $(filter_selector_string + ' div.DataTables_sort_wrapper').css 'display', 'inline-block'
            else
              if filter_container_id?
                columnObj.filter_container_selector = '#' + filter_container_id
              if $('#yadcf-filter-wrapper-' + columnObj.filter_container_selector).length == 0
                $(columnObj.filter_container_selector).append '<div id="yadcf-filter-wrapper-' + generateTableSelectorJQFriendly(columnObj.filter_container_selector) + '"></div>'
              filter_selector_string = '#yadcf-filter-wrapper-' + generateTableSelectorJQFriendly(columnObj.filter_container_selector)
            if columnObj.filter_type == 'select' or columnObj.filter_type == 'custom_func'
              #add a wrapper to hold both filter and reset button
              $(filter_selector_string).append '<div id="yadcf-filter-wrapper-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter-wrapper"></div>'
              filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper'
              if columnObj.filter_type == 'select'
                filterActionStr = 'onchange="yadcf.doFilter(this, \'' + table_selector_jq_friendly + '\', ' + column_number + ', \'' + filter_match_mode + '\');"'
                if columnObj.externally_triggered == true
                  filterActionStr = ''
                $(filter_selector_string).append '<select id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter ' + columnObj.style_class + '" ' + filterActionStr + ' onkeydown="yadcf.preventDefaultForEnter(event);" onmousedown="yadcf.stopPropagation(event);" onclick=\'yadcf.stopPropagation(event);\'>' + column_data + '</select>'
                if filter_reset_button_text != false
                  $(filter_selector_string).find('.yadcf-filter').after '<button type="button" ' + 'id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '-reset" onmousedown="yadcf.stopPropagation(event);" onclick="yadcf.stopPropagation(event);yadcf.doFilter(\'clear\', \'' + table_selector_jq_friendly + '\', ' + column_number + '); return false;" class="yadcf-filter-reset-button">' + filter_reset_button_text + '</button>'
              else
                filterActionStr = 'onchange="yadcf.doFilterCustomDateFunc(this, \'' + table_selector_jq_friendly + '\', ' + column_number + ');"'
                if columnObj.externally_triggered == true
                  filterActionStr = ''
                $(filter_selector_string).append '<select id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter ' + columnObj.style_class + '" ' + filterActionStr + ' onkeydown="yadcf.preventDefaultForEnter(event);" onmousedown="yadcf.stopPropagation(event);" onclick=\'yadcf.stopPropagation(event);\'>' + column_data + '</select>'
                if filter_reset_button_text != false
                  $(filter_selector_string).find('.yadcf-filter').after '<button type="button" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.doFilterCustomDateFunc(\'clear\', \'' + table_selector_jq_friendly + '\', ' + column_number + '); return false;" class="yadcf-filter-reset-button">' + filter_reset_button_text + '</button>'
                if settingsDt.oFeatures.bStateSave == true and settingsDt.oLoadedState
                  if settingsDt.oLoadedState.yadcfState and settingsDt.oLoadedState.yadcfState[table_selector_jq_friendly] and settingsDt.oLoadedState.yadcfState[table_selector_jq_friendly][column_number]
                    tmpStr = settingsDt.oLoadedState.yadcfState[table_selector_jq_friendly][column_number].from
                    if tmpStr == '-1' or tmpStr == undefined
                      $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val tmpStr
                    else
                      $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val(tmpStr).addClass 'inuse'
                if settingsDt.oFeatures.bServerSide != true
                  addCustomFunctionFilterCapability table_selector_jq_friendly, 'yadcf-filter-' + table_selector_jq_friendly + '-' + column_number, column_number
              if settingsDt.aoPreSearchCols[column_position].sSearch != ''
                tmpStr = settingsDt.aoPreSearchCols[column_position].sSearch
                tmpStr = yadcfParseMatchFilter(tmpStr, getOptions(oTable.selector)[column_number].filter_match_mode)
                $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val(tmpStr).addClass 'inuse'
              if columnObj.select_type?
                initializeSelectPlugin columnObj.select_type, $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number), columnObj.select_type_options
            else if columnObj.filter_type == 'multi_select' or columnObj.filter_type == 'multi_select_custom_func'
              #add a wrapper to hold both filter and reset button
              $(filter_selector_string).append '<div id="yadcf-filter-wrapper-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter-wrapper"></div>'
              filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper'
              if columnObj.filter_type == 'multi_select'
                filterActionStr = 'onchange="yadcf.doFilterMultiSelect(this, \'' + table_selector_jq_friendly + '\', ' + column_number + ', \'' + filter_match_mode + '\');"'
                if columnObj.externally_triggered == true
                  filterActionStr = ''
                $(filter_selector_string).append '<select multiple data-placeholder="' + filter_default_label + '" id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter ' + columnObj.style_class + '" ' + filterActionStr + ' onkeydown="yadcf.preventDefaultForEnter(event);" onmousedown="yadcf.stopPropagation(event);" onclick=\'yadcf.stopPropagation(event);\'>' + column_data + '</select>'
                if filter_reset_button_text != false
                  $(filter_selector_string).find('.yadcf-filter').after '<button type="button" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.doFilter(\'clear\', \'' + table_selector_jq_friendly + '\', ' + column_number + '); return false;" class="yadcf-filter-reset-button">' + filter_reset_button_text + '</button>'
                if settingsDt.aoPreSearchCols[column_position].sSearch != ''
                  tmpStr = settingsDt.aoPreSearchCols[column_position].sSearch
                  tmpStr = yadcfParseMatchFilterMultiSelect(tmpStr, getOptions(oTable.selector)[column_number].filter_match_mode)
                  tmpStr = tmpStr.replace(/\\/g, '')
                  tmpStr = tmpStr.split('|')
                  $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val tmpStr
              else
                filterActionStr = 'onchange="yadcf.doFilterCustomDateFunc(this, \'' + table_selector_jq_friendly + '\', ' + column_number + ');"'
                if columnObj.externally_triggered == true
                  filterActionStr = ''
                $(filter_selector_string).append '<select multiple data-placeholder="' + filter_default_label + '" id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter ' + columnObj.style_class + '" ' + filterActionStr + ' onkeydown="yadcf.preventDefaultForEnter(event);" onmousedown="yadcf.stopPropagation(event);" onclick=\'yadcf.stopPropagation(event);\'>' + column_data + '</select>'
                if filter_reset_button_text != false
                  $(filter_selector_string).find('.yadcf-filter').after '<button type="button" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.doFilterCustomDateFunc(\'clear\', \'' + table_selector_jq_friendly + '\', ' + column_number + '); return false;" class="yadcf-filter-reset-button">' + filter_reset_button_text + '</button>'
                if settingsDt.oFeatures.bStateSave == true and settingsDt.oLoadedState
                  if settingsDt.oLoadedState.yadcfState and settingsDt.oLoadedState.yadcfState[table_selector_jq_friendly] and settingsDt.oLoadedState.yadcfState[table_selector_jq_friendly][column_number]
                    tmpStr = settingsDt.oLoadedState.yadcfState[table_selector_jq_friendly][column_number].from
                    if tmpStr == '-1' or tmpStr == undefined
                      $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val tmpStr
                    else
                      $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val(tmpStr).addClass 'inuse'
                if settingsDt.oFeatures.bServerSide != true
                  addCustomFunctionFilterCapability table_selector_jq_friendly, 'yadcf-filter-' + table_selector_jq_friendly + '-' + column_number, column_number
              if columnObj.filter_container_selector == undefined and columnObj.select_type_options.width == undefined
                columnObj.select_type_options = $.extend(columnObj.select_type_options, width: $(filter_selector_string).closest('th').width() + 'px')
              if columnObj.filter_container_selector? and columnObj.select_type_options.width == undefined
                columnObj.select_type_options = $.extend(columnObj.select_type_options, width: $(filter_selector_string).closest(columnObj.filter_container_selector).width() + 'px')
              if columnObj.select_type?
                initializeSelectPlugin columnObj.select_type, $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number), columnObj.select_type_options
            else if columnObj.filter_type == 'auto_complete'
              #add a wrapper to hold both filter and reset button
              $(filter_selector_string).append '<div id="yadcf-filter-wrapper-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter-wrapper"></div>'
              filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper'
              filterActionStr = 'onkeyup="yadcf.autocompleteKeyUP(\'' + table_selector_jq_friendly + '\',event);"'
              if columnObj.externally_triggered == true
                filterActionStr = ''
              $(filter_selector_string).append '<input onkeydown="yadcf.preventDefaultForEnter(event);" id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter" onmousedown="yadcf.stopPropagation(event);" onclick=\'yadcf.stopPropagation(event);' + '\' placeholder=\'' + filter_default_label + '\'' + ' filter_match_mode=\'' + filter_match_mode + '\' ' + filterActionStr + '></input>'
              $(document).data 'yadcf-filter-' + table_selector_jq_friendly + '-' + column_number, column_data
              if filter_reset_button_text != false
                $(filter_selector_string).find('.yadcf-filter').after '<button type="button" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.doFilterAutocomplete(\'clear\', \'' + table_selector_jq_friendly + '\', ' + column_number + '); return false;" class="yadcf-filter-reset-button">' + filter_reset_button_text + '</button>'
            else if columnObj.filter_type == 'text'
              #add a wrapper to hold both filter and reset button
              $(filter_selector_string).append '<div id="yadcf-filter-wrapper-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter-wrapper"></div>'
              filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper'
              filterActionStr = 'onkeyup="yadcf.textKeyUP(event,\'' + table_selector_jq_friendly + '\', ' + column_number + ');"'
              if columnObj.externally_triggered == true
                filterActionStr = ''
              exclude_str = ''
              if columnObj.exclude == true
                if columnObj.externally_triggered != true
                  exclude_str = '<span class="yadcf-exclude-wrapper" onmousedown="yadcf.stopPropagation(event);" onclick="yadcf.stopPropagation(event);">' + '<div class="yadcf-label small">' + columnObj.exclude_label + '</div><input type="checkbox" title="' + columnObj.exclude_label + '" onclick="yadcf.stopPropagation(event);yadcf.textKeyUP(event,\'' + table_selector_jq_friendly + '\',' + column_number + ');"></span>'
                else
                  exclude_str = '<span class="yadcf-exclude-wrapper" onmousedown="yadcf.stopPropagation(event);" onclick="yadcf.stopPropagation(event);">' + '<div class="yadcf-label small">' + columnObj.exclude_label + '</div><input type="checkbox" title="' + columnObj.exclude_label + '" onclick="yadcf.stopPropagation(event);"></span>'
              $(filter_selector_string).append exclude_str + '<input type="text" onkeydown="yadcf.preventDefaultForEnter(event);" id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '" class="yadcf-filter ' + columnObj.style_class + '" onmousedown="yadcf.stopPropagation(event);" onclick=\'yadcf.stopPropagation(event);' + '\' placeholder=\'' + filter_default_label + '\'' + ' filter_match_mode=\'' + filter_match_mode + '\' ' + filterActionStr + '></input>'
              if filter_reset_button_text != false
                $(filter_selector_string).find('.yadcf-filter').after '<button type="button" ' + ' id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '-reset" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.textKeyUP(event,\'' + table_selector_jq_friendly + '\', \'' + column_number + '\', \'clear\'); return false;" class="yadcf-filter-reset-button">' + filter_reset_button_text + '</button>'
              if settingsDt.aoPreSearchCols[column_position].sSearch != ''
                tmpStr = settingsDt.aoPreSearchCols[column_position].sSearch
                if columnObj.exclude == true
                  if tmpStr.indexOf('^((?!') != -1
                    $('#yadcf-filter-wrapper-' + table_selector_jq_friendly + '-' + column_number).find(':checkbox').prop 'checked', true
                  tmpStr = tmpStr.substring(5, tmpStr.indexOf(').)'))
                tmpStr = yadcfParseMatchFilter(tmpStr, getOptions(oTable.selector)[column_number].filter_match_mode)
                $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val(tmpStr).addClass 'inuse'
            else if columnObj.filter_type == 'date'
              addDateFilter filter_selector_string, table_selector_jq_friendly, column_number, filter_reset_button_text, filter_default_label, date_format
            else if columnObj.filter_type == 'range_number'
              addRangeNumberFilter filter_selector_string, table_selector_jq_friendly, column_number, filter_reset_button_text, filter_default_label, ignore_char
            else if columnObj.filter_type == 'range_number_slider'
              addRangeNumberSliderFilter filter_selector_string, table_selector_jq_friendly, column_number, filter_reset_button_text, min_val, max_val, ignore_char
            else if columnObj.filter_type == 'range_date'
              addRangeDateFilter filter_selector_string, table_selector_jq_friendly, column_number, filter_reset_button_text, filter_default_label, date_format
          if $(document).data('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val')? and $(document).data('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val') != '-1'
            $(filter_selector_string).find('.yadcf-filter').val $(document).data('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val')
          if columnObj.filter_type == 'auto_complete'
            if columnObj.filter_plugin_options?
              if columnObj.filter_plugin_options.source == undefined
                columnObj.filter_plugin_options.source = $(document).data('yadcf-filter-' + table_selector_jq_friendly + '-' + column_number)
              columnObj.filter_plugin_options.select = autocompleteSelect
            else
              columnObj.filter_plugin_options =
                source: $(document).data('yadcf-filter-' + table_selector_jq_friendly + '-' + column_number)
                select: autocompleteSelect
            if columnObj.externally_triggered == true
              delete columnObj.filter_plugin_options.select
            $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).autocomplete columnObj.filter_plugin_options
            if settingsDt.aoPreSearchCols[column_position].sSearch != ''
              tmpStr = settingsDt.aoPreSearchCols[column_position].sSearch
              tmpStr = yadcfParseMatchFilter(tmpStr, getOptions(oTable.selector)[column_number].filter_match_mode)
              $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val(tmpStr).addClass 'inuse'
      if exFilterColumnQueue.length > 0
        exFilterColumnQueue.shift()()
      return

    endsWith = (str, suffix) ->
      str.indexOf(suffix, str.length - (suffix.length)) != -1

    rangeClear = (table_selector_jq_friendly, event, column_number) ->
      event = eventTargetFixUp(event)
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      yadcfState = undefined
      settingsDt = undefined
      column_number_filter = undefined
      currentFilterValues = undefined
      columnObj = undefined
      settingsDt = getSettingsObjFromTable(oTable)
      column_number_filter = calcColumnNumberFilter(settingsDt, column_number, table_selector_jq_friendly)
      currentFilterValues = exGetColumnFilterVal(oTable, column_number)
      if currentFilterValues.from == '' and currentFilterValues.to == ''
        return
      columnObj = getOptions(oTable.selector)[column_number]
      if columnObj.filter_type == 'range_date' and columnObj.datepicker_type == 'bootstrap-datetimepicker'
        $($(event.target).parent().find('.yadcf-filter-range')[0]).data('DateTimePicker').maxDate false
        $($(event.target).parent().find('.yadcf-filter-range')[1]).data('DateTimePicker').minDate false
      $(event.target).parent().parent().find('.yadcf-filter-range').val ''
      if $(event.target).parent().find('.yadcf-filter-range-number').length > 0
        $($(event.target).parent().find('.yadcf-filter-range')[0]).focus()
      if oTable.fnSettings().oFeatures.bServerSide != true
        oTable.fnDraw()
      else
        oTable.fnFilter '-yadcf_delim-', column_number_filter
      if !oTable.fnSettings().oLoadedState
        oTable.fnSettings().oLoadedState = {}
        oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
      if oTable.fnSettings().oFeatures.bStateSave == true
        if oTable.fnSettings().oLoadedState.yadcfState? and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly]?
          oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number] =
            'from': ''
            'to': ''
        else
          yadcfState = {}
          yadcfState[table_selector_jq_friendly] = []
          yadcfState[table_selector_jq_friendly][column_number] =
            'from': ''
            'to': ''
          oTable.fnSettings().oLoadedState.yadcfState = yadcfState
        oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
      resetIApiIndex()
      $(event.target).parent().parent().find('.yadcf-filter-range').removeClass 'inuse'
      return

    rangeNumberSliderClear = (table_selector_jq_friendly, event) ->
      event = eventTargetFixUp(event)
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      min_val = undefined
      max_val = undefined
      currentFilterValues = undefined
      column_number = undefined
      column_number = parseInt($(event.target).prev().find('.yadcf-filter-range-number-slider').attr('id').replace('yadcf-filter-' + table_selector_jq_friendly + '-slider-', ''), 10)
      min_val = +$($(event.target).parent().find('.yadcf-filter-range-number-slider-min-tip-hidden')).text()
      max_val = +$($(event.target).parent().find('.yadcf-filter-range-number-slider-max-tip-hidden')).text()
      currentFilterValues = exGetColumnFilterVal(oTable, column_number)
      if +currentFilterValues.from == min_val and +currentFilterValues.to == max_val
        return
      $('#' + $(event.target).prev().find('.yadcf-filter-range-number-slider').attr('id')).slider 'option', 'yadcf-reset', true
      $('#' + $(event.target).prev().find('.yadcf-filter-range-number-slider').attr('id')).slider 'option', 'values', [
        min_val
        max_val
      ]
      $($(event.target).prev().find('.ui-slider-handle')[0]).attr('tabindex', -1).focus()
      $($(event.target).prev().find('.ui-slider-handle')[0]).removeClass 'inuse'
      $($(event.target).prev().find('.ui-slider-handle')[1]).removeClass 'inuse'
      $(event.target).prev().find('.ui-slider-range').removeClass 'inuse'
      oTable.fnDraw()
      resetIApiIndex()
      return

    dateKeyUP = (table_selector_jq_friendly, date_format, event) ->
      oTable = undefined
      date = undefined
      dateId = undefined
      column_number = undefined
      columnObj = undefined
      event = eventTargetFixUp(event)
      dateId = event.target.id
      date = document.getElementById(dateId).value
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      column_number = parseInt(dateId.replace('yadcf-filter-' + table_selector_jq_friendly + '-', ''), 10)
      columnObj = getOptions(oTable.selector)[column_number]
      try
        if columnObj.datepicker_type == 'jquery-ui'
          if date.length == date_format.length + 2
            date = if date != '' then $.datepicker.parseDate(date_format, date) else date
      catch err1
      if date instanceof Date or moment(date, columnObj.date_format).isValid()
        $('#' + dateId).addClass 'inuse'
        oTable.fnFilter document.getElementById(dateId).value, column_number
        resetIApiIndex()
      else if date == '' or $.trim(event.target.value) == ''
        $('#' + dateId).removeClass 'inuse'
        $('#' + event.target.id).removeClass 'inuse'
        oTable.fnFilter '', column_number
        resetIApiIndex()
      return

    rangeDateKeyUP = (table_selector_jq_friendly, date_format, event) ->
      event = eventTargetFixUp(event)
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      min = undefined
      max = undefined
      fromId = undefined
      toId = undefined
      column_number = undefined
      options = undefined
      keyUp = undefined
      settingsDt = undefined
      column_number_filter = undefined
      column_number = parseInt($(event.target).attr('id').replace('-from-date-', '').replace('-to-date-', '').replace('yadcf-filter-' + table_selector_jq_friendly, ''), 10)
      options = getOptions(oTable.selector)[column_number]
      settingsDt = getSettingsObjFromTable(oTable)
      column_number_filter = calcColumnNumberFilter(settingsDt, column_number, table_selector_jq_friendly)

      keyUp = ->
        if event.target.id.indexOf('-from-') != -1
          fromId = event.target.id
          toId = event.target.id.replace('-from-', '-to-')
          min = document.getElementById(fromId).value
          max = document.getElementById(toId).value
        else
          toId = event.target.id
          fromId = event.target.id.replace('-to-', '-from-')
          max = document.getElementById(toId).value
          min = document.getElementById(fromId).value
        try
          if min.length == date_format.length + 2
            min = if min != '' then $.datepicker.parseDate(date_format, min) else min
        catch err1
        try
          if max.length == date_format.length + 2
            max = if max != '' then $.datepicker.parseDate(date_format, max) else max
        catch err2
        if max instanceof Date and min instanceof Date and max >= min or min == '' or max == ''
          if oTable.fnSettings().oFeatures.bServerSide != true
            oTable.fnDraw()
          else
            oTable.fnFilter document.getElementById(fromId).value + '-yadcf_delim-' + document.getElementById(toId).value, column_number_filter
          if min instanceof Date
            $('#' + fromId).addClass 'inuse'
          else
            $('#' + fromId).removeClass 'inuse'
          if max instanceof Date
            $('#' + toId).addClass 'inuse'
          else
            $('#' + toId).removeClass 'inuse'
          if $.trim(event.target.value) == '' and $(event.target).hasClass('inuse')
            $('#' + event.target.id).removeClass 'inuse'
        resetIApiIndex()
        return

      if options.filter_delay == undefined
        keyUp table_selector_jq_friendly, event
      else
        yadcfDelay (->
          keyUp table_selector_jq_friendly, event
          return
        ), options.filter_delay
      return

    rangeNumberKeyUP = (table_selector_jq_friendly, event) ->
      event = eventTargetFixUp(event)
      $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
      oTable = oTables[table_selector_jq_friendly]
      min = undefined
      max = undefined
      fromId = undefined
      toId = undefined
      yadcfState = undefined
      column_number = undefined
      options = undefined
      keyUp = undefined
      column_number = parseInt($(event.target).attr('id').replace('-from-', '').replace('-to-', '').replace('yadcf-filter-' + table_selector_jq_friendly, ''), 10)
      options = getOptions(oTable.selector)[column_number]

      keyUp = ->
        if event.target.id.indexOf('-from-') != -1
          fromId = event.target.id
          toId = event.target.id.replace('-from-', '-to-')
          min = document.getElementById(fromId).value
          max = document.getElementById(toId).value
        else
          toId = event.target.id
          fromId = event.target.id.replace('-to-', '-from-')
          max = document.getElementById(toId).value
          min = document.getElementById(fromId).value
        min = if min != '' then +min else min
        max = if max != '' then +max else max
        if !isNaN(max) and !isNaN(min) and max >= min or min == '' or max == ''
          if oTable.fnSettings().oFeatures.bServerSide != true
            oTable.fnDraw()
          else
            oTable.fnFilter min + '-yadcf_delim-' + max, column_number
          if document.getElementById(fromId).value != ''
            $('#' + fromId).addClass 'inuse'
          if document.getElementById(toId).value != ''
            $('#' + toId).addClass 'inuse'
          if $.trim(event.target.value) == '' and $(event.target).hasClass('inuse')
            $('#' + event.target.id).removeClass 'inuse'
          if !oTable.fnSettings().oLoadedState
            oTable.fnSettings().oLoadedState = {}
            oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
          if oTable.fnSettings().oFeatures.bStateSave == true
            if oTable.fnSettings().oLoadedState.yadcfState? and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly]?
              oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number] =
                'from': min
                'to': max
            else
              yadcfState = {}
              yadcfState[table_selector_jq_friendly] = []
              yadcfState[table_selector_jq_friendly][column_number] =
                'from': min
                'to': max
              oTable.fnSettings().oLoadedState.yadcfState = yadcfState
            oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
        resetIApiIndex()
        return

      if options.filter_delay == undefined
        keyUp()
      else
        yadcfDelay (->
          keyUp()
          return
        ), options.filter_delay
      return

    doFilterMultiTablesMultiSelect = (tablesSelectors, event, column_number_str, clear) ->
      columnsObj = getOptions(tablesSelectors + '_' + column_number_str)[column_number_str]
      regex = false
      smart = true
      caseInsen = true
      tablesAsOne = undefined
      tablesArray = oTables[tablesSelectors]
      selected_values = $(event.target).val()
      i = undefined
      event = eventTargetFixUp(event)
      tablesAsOne = new ($.fn.dataTable.Api)(tablesArray)
      if clear? or selected_values == undefined or selected_values.length == 0
        if clear?
          $(event.target).parent().find('select').val('-1').focus()
          $(event.target).parent().find('selectn ').removeClass 'inuse'
        if columnsObj.column_number instanceof Array
          tablesAsOne.columns(columnsObj.column_number).search('').draw()
        else
          tablesAsOne.search('').draw()
        refreshSelectPlugin columnsObj, $('#' + columnsObj.filter_container_id + ' select'), '-1'
        return
      $(event.target).addClass 'inuse'
      regex = true
      smart = false
      caseInsen = columnsObj.case_insensitive
      if selected_values?
        i = selected_values.length - 1
        while i >= 0
          if selected_values[i] == '-1'
            selected_values.splice i, 1
            break
          i--
        if selected_values.length != 0
          selected_values = selected_values.join('narutouzomaki')
          selected_values = selected_values.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, '\\$1')
          selected_values = selected_values.split('narutouzomaki').join('|')
      if columnsObj.filter_match_mode == 'exact'
        selected_values = '^' + selected_values + '$'
      else if columnsObj.filter_match_mode == 'startsWith'
        selected_values = '^' + selected_values
      if columnsObj.column_number instanceof Array
        tablesAsOne.columns(columnsObj.column_number).search(selected_values, regex, smart, caseInsen).draw()
      else
        tablesAsOne.search(selected_values, regex, smart, caseInsen).draw()
      return

    doFilterMultiTables = (tablesSelectors, event, column_number_str, clear) ->
      columnsObj = getOptions(tablesSelectors + '_' + column_number_str)[column_number_str]
      regex = false
      smart = true
      caseInsen = true
      serachVal = undefined
      tablesAsOne = undefined
      tablesArray = oTables[tablesSelectors]
      event = eventTargetFixUp(event)
      tablesAsOne = new ($.fn.dataTable.Api)(tablesArray)
      if clear? or event.target.value == '-1'
        if clear?
          $(event.target).parent().find('select').val('-1').focus()
          $(event.target).parent().find('select').removeClass 'inuse'
        if columnsObj.column_number instanceof Array
          tablesAsOne.columns(columnsObj.column_number).search('').draw()
        else
          tablesAsOne.search('').draw()
        refreshSelectPlugin columnsObj, $('#' + columnsObj.filter_container_id + ' select'), '-1'
        return
      $(event.target).addClass 'inuse'
      serachVal = event.target.value
      smart = false
      caseInsen = columnsObj.case_insensitive
      if columnsObj.column_number instanceof Array
        tablesAsOne.columns(columnsObj.column_number).search(serachVal, regex, smart, caseInsen).draw()
      else
        tablesAsOne.search(serachVal, regex, smart, caseInsen).draw()
      return

    textKeyUpMultiTables = (tablesSelectors, event, column_number_str, clear) ->
      keyUp = undefined
      columnsObj = getOptions(tablesSelectors + '_' + column_number_str)[column_number_str]
      regex = false
      smart = true
      caseInsen = true
      serachVal = undefined
      tablesAsOne = undefined
      tablesArray = oTables[tablesSelectors]
      event = eventTargetFixUp(event)
      tablesAsOne = new ($.fn.dataTable.Api)(tablesArray)

      keyUp = (tablesAsOne, event, clear) ->
        if clear? or event.target.value == ''
          if clear?
            $(event.target).prev().val('').focus()
            $(event.target).prev().removeClass 'inuse'
          else
            $(event.target).val('').focus()
            $(event.target).removeClass 'inuse'
          if columnsObj.column_number instanceof Array
            tablesAsOne.columns(columnsObj.column_number).search('').draw()
          else
            tablesAsOne.search('').draw()
          return
        $(event.target).addClass 'inuse'
        serachVal = event.target.value
        smart = false
        caseInsen = columnsObj.case_insensitive
        if columnsObj.column_number instanceof Array
          tablesAsOne.columns(columnsObj.column_number).search(serachVal, regex, smart, caseInsen).draw()
        else
          tablesAsOne.search(serachVal, regex, smart, caseInsen).draw()
        return

      if columnsObj.filter_delay == undefined
        keyUp tablesAsOne, event, clear
      else
        yadcfDelay (->
          keyUp tablesAsOne, event, clear
          return
        ), columnsObj.filter_delay
      return

    textKeyUP = (ev, table_selector_jq_friendly, column_number, clear) ->
      column_number_filter = undefined
      oTable = oTables[table_selector_jq_friendly]
      keyUp = undefined
      columnObj = undefined
      settingsDt = getSettingsObjFromTable(oTable)
      exclude = undefined
      keyCodes = [
        37
        38
        39
        40
      ]
      if keyCodes.indexOf(ev.keyCode) != -1
        return
      column_number_filter = calcColumnNumberFilter(settingsDt, column_number, table_selector_jq_friendly)
      columnObj = getOptions(oTable.selector)[column_number]

      keyUp = (table_selector_jq_friendly, column_number, clear) ->
        $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
        if clear == 'clear' or $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val() == ''
          if clear == 'clear' and exGetColumnFilterVal(oTable, column_number) == ''
            return
          $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val('').focus()
          $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).removeClass 'inuse'
          oTable.fnFilter '', column_number_filter
          resetIApiIndex()
          return
        if columnObj.exclude == true
          exclude = $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).closest('.yadcf-filter-wrapper').find('.yadcf-exclude-wrapper :checkbox').prop('checked')
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).addClass 'inuse'
        yadcfMatchFilter oTable, $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val(), columnObj.filter_match_mode, column_number_filter, exclude
        resetIApiIndex()
        return

      if columnObj.filter_delay == undefined
        keyUp table_selector_jq_friendly, column_number, clear
      else
        yadcfDelay (->
          keyUp table_selector_jq_friendly, column_number, clear
          return
        ), columnObj.filter_delay
      return

    autocompleteKeyUP = (table_selector_jq_friendly, event) ->
      oTable = undefined
      column_number = undefined
      keyCodes = [
        37
        38
        39
        40
      ]
      event = eventTargetFixUp(event)
      if keyCodes.indexOf(event.keyCode) != -1
        return
      if event.target.value == '' and event.keyCode == 8 and $(event.target).hasClass('inuse')
        $.fn.dataTableExt.iApiIndex = oTablesIndex[table_selector_jq_friendly]
        oTable = oTables[table_selector_jq_friendly]
        column_number = parseInt($(event.target).attr('id').replace('yadcf-filter-' + table_selector_jq_friendly + '-', ''), 10)
        $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).removeClass 'inuse'
        $(document).removeData '#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val'
        oTable.fnFilter '', column_number
        resetIApiIndex()
      return

    isDOMSource = (tableVar) ->
      settingsDt = undefined
      settingsDt = getSettingsObjFromTable(tableVar)
      if settingsDt.sAjaxSource == undefined and settingsDt.ajax == undefined
        return true
      false

    scrollXYHandler = (oTable, table_selector) ->
      $tmpSelector = undefined
      filters_position = $(document).data(table_selector + '_filters_position')
      table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendly(table_selector)
      if filters_position == 'thead'
        filters_position = '.dataTables_scrollHead'
      else
        filters_position = '.dataTables_scrollFoot'
      if oTable.fnSettings().oScroll.sX != '' or oTable.fnSettings().oScroll.sY != ''
        $tmpSelector = $(table_selector).closest('.dataTables_scroll').find(filters_position + ' table')
        $tmpSelector.addClass 'yadcf-datatables-table-' + table_selector_jq_friendly
      return

    firstFromObject = (obj) ->
      for key of obj
        if obj.hasOwnProperty(key)
          return key
      return

    initAndBindTable = (oTable, table_selector, index, pTableDT) ->
      table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendly(table_selector)
      table_selector_tmp = undefined
      oTables[table_selector_jq_friendly] = oTable
      tablesDT[table_selector_jq_friendly] = pTableDT
      oTablesIndex[table_selector_jq_friendly] = index
      scrollXYHandler oTable, table_selector
      if isDOMSource(oTable)
        table_selector_tmp = table_selector
        if table_selector.indexOf(':eq') != -1
          table_selector_tmp = table_selector.substring(0, table_selector.lastIndexOf(':eq'))
        appendFilters oTable, getOptions(table_selector_tmp), table_selector
        if getOptions(table_selector_tmp)[firstFromObject(getOptions(table_selector_tmp))].cumulative_filtering == true
          # when filters should be populated only from visible rows (non filtered)
          $(document).off('search.dt', oTable.selector).on 'search.dt', oTable.selector, (e, settings, json) ->
            table_selector_tmp = oTable.selector
            if table_selector.indexOf(':eq') != -1
              table_selector_tmp = table_selector.substring(0, table_selector.lastIndexOf(':eq'))
            appendFilters oTable, getOptions(table_selector_tmp), oTable.selector
            return
      else
        appendFilters oTable, getOptions(table_selector), table_selector
        if yadcfVersionCheck('1.10')
          $(document).off('xhr.dt', oTable.selector).on 'xhr.dt', oTable.selector, (e, settings, json) ->
            column_number_filter = undefined
            table_selector_jq_friendly = generateTableSelectorJQFriendly(oTable.selector)
            if json == undefined
              console.log 'datatables xhr.dt event came back with null as data (nothing for yadcf to do with it).'
              return
            if settings.oSavedState?
              initColReorder2 settings, table_selector_jq_friendly
            for col_num of yadcf.getOptions(settings.oInstance.selector)
              if yadcf.getOptions(settings.oInstance.selector).hasOwnProperty(col_num)
                if json['yadcf_data_' + col_num]?
                  column_number_filter = col_num
                  if settings.oSavedState? and plugins[table_selector_jq_friendly]?
                    column_number_filter = plugins[table_selector_jq_friendly].ColReorder[col_num]
                  yadcf.getOptions(settings.oInstance.selector)[col_num].data = json['yadcf_data_' + column_number_filter]
            return
      # events that affects both DOM and Ajax
      if yadcfVersionCheck('1.10')
        $(document).off('draw.dt', oTable.selector).on 'draw.dt', oTable.selector, (event, settings) ->
          appendFilters oTable, yadcf.getOptions(settings.oInstance.selector), settings.oInstance.selector
          return
        $(document).off('column-visibility.dt', oTable.selector).on 'column-visibility.dt', oTable.selector, (e, settings, col_num, state) ->
          obj = {}
          columnsObj = getOptions(settings.oInstance.selector)
          if state == true and settings._oFixedColumns == undefined
            if plugins[table_selector_jq_friendly]? and plugins[table_selector_jq_friendly].ColReorder?
              col_num = plugins[table_selector_jq_friendly].ColReorder[col_num]
            else if settings.oSavedState? and settings.oSavedState.ColReorder?
              col_num = settings.oSavedState.ColReorder[col_num]
            obj[col_num] = yadcf.getOptions(settings.oInstance.selector)[col_num]
            if obj[col_num]?
              obj[col_num].column_number = col_num
              if obj[col_num]?
                appendFilters oTables[yadcf.generateTableSelectorJQFriendly(settings.oInstance.selector)], obj, settings.oInstance.selector
          else if settings._oFixedColumns?
            appendFilters oTables[yadcf.generateTableSelectorJQFriendly(settings.oInstance.selector)], columnsObj, settings.oInstance.selector
          return
        $(document).off('column-reorder.dt', oTable.selector).on 'column-reorder.dt', oTable.selector, (e, settings, json) ->
          `var table_selector_jq_friendly`
          table_selector_jq_friendly = generateTableSelectorJQFriendly(oTable.selector)
          initColReorderFromEvent table_selector_jq_friendly
          return
        $(document).off('destroy.dt', oTable.selector).on 'destroy.dt', oTable.selector, (event, ui) ->
          removeFilters oTable, yadcf.getOptions(ui.oInstance.selector), ui.oInstance.selector
          return
      else
        $(document).off('draw', oTable.selector).on 'draw', oTable.selector, (event, ui) ->
          appendFilters oTable, yadcf.getOptions(ui.oInstance.selector), ui.oInstance.selector
          return
        $(document).off('destroy', oTable.selector).on 'destroy', oTable.selector, (event, ui) ->
          removeFilters oTable, yadcf.getOptions(ui.oInstance.selector), ui.oInstance.selector
          return
      if oTable.fnSettings().oFeatures.bStateSave == true
        if yadcfVersionCheck('1.10')
          $(oTable.selector).off('stateSaveParams.dt').on 'stateSaveParams.dt', (e, settings, data) ->
            if settings.oLoadedState and settings.oLoadedState.yadcfState?
              data.yadcfState = settings.oLoadedState.yadcfState
            else
              data.naruto = 'kurama'
            return
        else
          $(oTable.selector).off('stateSaveParams').on 'stateSaveParams', (e, settings, data) ->
            if settings.oLoadedState and settings.oLoadedState.yadcfState?
              data.yadcfState = settings.oLoadedState.yadcfState
            else
              data.naruto = 'kurama'
            return
        #when using DOM source
        if isDOMSource(oTable)
          #we need to make sure that the yadcf state will be saved after page reload
          oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
          #redraw the table in order to apply the filters
          oTable.fnDraw false
      return

    init = (oTable, options_arg, params) ->
      instance = oTable.settings()[0].oInstance
      i = 0
      selector = undefined
      tmpParams = undefined
      tableSelector = '#' + oTable.table().node().id
      # in case that instance.selector will be undefined (jQuery 3)
      if instance.selector == undefined
        instance.selector = tableSelector
      if params == undefined
        params = {}
      if typeof params == 'string'
        tmpParams = params
        params = {}
        params.filters_position = tmpParams
      if params.filters_position == undefined or params.filters_position == 'header'
        params.filters_position = 'thead'
      else
        params.filters_position = 'tfoot'
      $(document).data instance.selector + '_filters_position', params.filters_position
      if $(instance.selector).length == 1
        setOptions instance.selector, options_arg, params
        initAndBindTable instance, instance.selector, 0, oTable
      else
        i
        while i < $(instance.selector).length
          $.fn.dataTableExt.iApiIndex = i
          selector = instance.selector + ':eq(' + i + ')'
          setOptions instance.selector, options_arg, params
          initAndBindTable instance, selector, i, oTable
          i++
        $.fn.dataTableExt.iApiIndex = 0
      return

    appendFiltersMultipleTables = (tablesArray, tablesSelectors, colObjDummy) ->
      filter_selector_string = '#' + colObjDummy.filter_container_id
      $filter_selector = $(filter_selector_string).find('.yadcf-filter')
      table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendlyNew(tablesSelectors)
      options_tmp = undefined
      ii = undefined
      column_number_str = columnsArrayToString(colObjDummy.column_number).column_number_str
      tableTmp = undefined
      tableTmpArr = undefined
      tableTmpArrIndex = undefined
      filterOptions = getOptions(tablesSelectors + '_' + column_number_str)[column_number_str]
      column_number_index = undefined
      columnsTmpArr = undefined
      settingsDt = undefined
      tmpStr = undefined
      columnForStateSaving = undefined
      #add a wrapper to hold both filter and reset button
      $(filter_selector_string).append '<div id="yadcf-filter-wrapper-' + table_selector_jq_friendly + '-' + column_number_str + '" class="yadcf-filter-wrapper"></div>'
      filter_selector_string = filter_selector_string + ' div.yadcf-filter-wrapper'
      if column_number_str.indexOf('_') != -1
        columnForStateSaving = column_number_str.split('_')[0]
      else
        columnForStateSaving = column_number_str
      switch filterOptions.filter_type
        when 'text'
          $(filter_selector_string).append '<input type="text" id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number_str + '" class="yadcf-filter" onmousedown="yadcf.stopPropagation(event);" onclick=\'yadcf.stopPropagation(event);' + '\' placeholder=\'' + filterOptions.filter_default_label + '\'' + ' onkeyup="yadcf.textKeyUpMultiTables(\'' + tablesSelectors + '\',event,\'' + column_number_str + '\');"></input>'
          if filterOptions.filter_reset_button_text != false
            $(filter_selector_string).find('.yadcf-filter').after '<button type="button" ' + ' id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number_str + '-reset" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.textKeyUpMultiTables(\'' + tablesSelectors + '\', event,\'' + column_number_str + '\',\'clear\'); return false;" class="yadcf-filter-reset-button">' + filterOptions.filter_reset_button_text + '</button>'
          if tablesArray[0].table?
            tableTmp = $('#' + tablesArray[0].table().node().id).dataTable()
          else
            tableTmp = tablesArray[0]
          settingsDt = getSettingsObjFromTable(tableTmp)
          if settingsDt.aoPreSearchCols[columnForStateSaving].sSearch != ''
            tmpStr = settingsDt.aoPreSearchCols[columnForStateSaving].sSearch
            tmpStr = yadcfParseMatchFilter(tmpStr, filterOptions.filter_match_mode)
            $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number_str).val(tmpStr).addClass 'inuse'
        when 'select', 'multi_select'
          if filterOptions.select_type == undefined
            options_tmp = '<option data-placeholder="true" value="' + '-1' + '">' + filterOptions.filter_default_label + '</option>'
          else
            options_tmp = ''
          if filterOptions.select_type == 'select2' and filterOptions.select_type_options.placeholder? and filterOptions.select_type_options.allowClear == true
            options_tmp = '<option value=""></option>'
          if filterOptions.data == undefined
            filterOptions.data = []
            tableTmpArr = tablesSelectors.split(',')
            tableTmpArrIndex = 0
            while tableTmpArrIndex < tableTmpArr.length
              if tablesArray[tableTmpArrIndex].table?
                tableTmp = $('#' + tablesArray[tableTmpArrIndex].table().node().id).dataTable()
              else
                tableTmp = tablesArray[tableTmpArrIndex]
              if isDOMSource(tableTmp)
                #check if ajax source, if so, listen for dt.draw
                columnsTmpArr = filterOptions.column_number
                column_number_index = 0
                while column_number_index < columnsTmpArr.length
                  filterOptions.column_number = columnsTmpArr[column_number_index]
                  filterOptions.data = filterOptions.data.concat(parseTableColumn(tableTmp, filterOptions, table_selector_jq_friendly))
                  column_number_index++
                filterOptions.column_number = columnsTmpArr
              else
                $(document).off('draw.dt', '#' + tablesArray[tableTmpArrIndex].table().node().id).on 'draw.dt', '#' + tablesArray[tableTmpArrIndex].table().node().id, (event, ui) ->
                  options_tmp = ''
                  columnsTmpArr = filterOptions.column_number
                  column_number_index = 0
                  while column_number_index < columnsTmpArr.length
                    filterOptions.column_number = columnsTmpArr[column_number_index]
                    filterOptions.data = filterOptions.data.concat(parseTableColumn(tableTmp, filterOptions, table_selector_jq_friendly))
                    column_number_index++
                  filterOptions.column_number = columnsTmpArr
                  filterOptions.data = sortColumnData(filterOptions.data, filterOptions)
                  ii = 0
                  while ii < filterOptions.data.length
                    options_tmp += '<option value="' + filterOptions.data[ii] + '">' + filterOptions.data[ii] + '</option>'
                    ii++
                  $('#' + filterOptions.filter_container_id + ' select').empty().append options_tmp
                  if filterOptions.select_type?
                    initializeSelectPlugin filterOptions.select_type, $('#' + filterOptions.filter_container_id + ' select'), filterOptions.select_type_options
                  return
              tableTmpArrIndex++
          filterOptions.data = sortColumnData(filterOptions.data, filterOptions)
          if tablesArray[0].table?
            tableTmp = $('#' + tablesArray[0].table().node().id).dataTable()
          else
            tableTmp = tablesArray[0]
          settingsDt = getSettingsObjFromTable(tableTmp)
          if typeof filterOptions.data[0] == 'object'
            ii = 0
            while ii < filterOptions.data.length
              options_tmp += '<option value="' + filterOptions.data[ii].value + '">' + filterOptions.data[ii].label + '</option>'
              ii++
          else
            ii = 0
            while ii < filterOptions.data.length
              options_tmp += '<option value="' + filterOptions.data[ii] + '">' + filterOptions.data[ii] + '</option>'
              ii++
          if filterOptions.filter_type == 'select'
            $(filter_selector_string).append '<select id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number_str + '" class="yadcf-filter" ' + 'onchange="yadcf.doFilterMultiTables(\'' + tablesSelectors + '\',event,\'' + column_number_str + '\')" onmousedown="yadcf.stopPropagation(event);" onclick=\'yadcf.stopPropagation(event);\'>' + options_tmp + '</select>'
            if settingsDt.aoPreSearchCols[columnForStateSaving].sSearch != ''
              tmpStr = settingsDt.aoPreSearchCols[columnForStateSaving].sSearch
              tmpStr = yadcfParseMatchFilter(tmpStr, filterOptions.filter_match_mode)
              $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number_str).val(tmpStr).addClass 'inuse'
          else if filterOptions.filter_type == 'multi_select'
            $(filter_selector_string).append '<select multiple data-placeholder="' + filterOptions.filter_default_label + '" id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number_str + '" class="yadcf-filter" ' + 'onchange="yadcf.doFilterMultiTablesMultiSelect(\'' + tablesSelectors + '\',event,\'' + column_number_str + '\')" onmousedown="yadcf.stopPropagation(event);" onclick=\'yadcf.stopPropagation(event);\'>' + options_tmp + '</select>'
            if settingsDt.aoPreSearchCols[columnForStateSaving].sSearch != ''
              tmpStr = settingsDt.aoPreSearchCols[columnForStateSaving].sSearch
              tmpStr = yadcfParseMatchFilterMultiSelect(tmpStr, filterOptions.filter_match_mode)
              tmpStr = tmpStr.replace(/\\/g, '')
              tmpStr = tmpStr.split('|')
              $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number_str).val tmpStr
          if filterOptions.filter_type == 'select'
            if filterOptions.filter_reset_button_text != false
              $(filter_selector_string).find('.yadcf-filter').after '<button type="button" ' + ' id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number_str + '-reset" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.doFilterMultiTables(\'' + tablesSelectors + '\', event,\'' + column_number_str + '\',\'clear\'); return false;" class="yadcf-filter-reset-button">' + filterOptions.filter_reset_button_text + '</button>'
          else if filterOptions.filter_type == 'multi_select'
            if filterOptions.filter_reset_button_text != false
              $(filter_selector_string).find('.yadcf-filter').after '<button type="button" ' + ' id="yadcf-filter-' + table_selector_jq_friendly + '-' + column_number_str + '-reset" onmousedown="yadcf.stopPropagation(event);" ' + 'onclick="yadcf.stopPropagation(event);yadcf.doFilterMultiTablesMultiSelect(\'' + tablesSelectors + '\', event,\'' + column_number_str + '\',\'clear\'); return false;" class="yadcf-filter-reset-button">' + filterOptions.filter_reset_button_text + '</button>'
          if filterOptions.select_type?
            initializeSelectPlugin filterOptions.select_type, $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number_str), filterOptions.select_type_options
        else
          alert 'Filters Multiple Tables does not support ' + filterOptions.filter_type
      return

    initMultipleTables = (tablesArray, filtersOptions) ->
      i = undefined
      tablesSelectors = ''
      default_options =
        filter_type: 'text'
        filter_container_id: ''
        filter_reset_button_text: 'x'
        case_insensitive: true
      columnsObjKey = undefined
      columnsObj = undefined
      columnsArrIndex = undefined
      column_number_str = undefined
      dummyArr = undefined
      columnsArrIndex = 0
      while columnsArrIndex < filtersOptions.length
        dummyArr = []
        columnsObj = filtersOptions[columnsArrIndex]
        if columnsObj.filter_default_label == undefined
          if columnsObj.filter_type == 'select' or columnsObj.filter_type == 'custom_func'
            columnsObj.filter_default_label = 'Select value'
          else if columnsObj.filter_type == 'multi_select' or columnsObj.filter_type == 'multi_select_custom_func'
            columnsObj.filter_default_label = 'Select values'
          else if columnsObj.filter_type == 'auto_complete' or columnsObj.filter_type == 'text'
            columnsObj.filter_default_label = 'Type to filter'
          else if columnsObj.filter_type == 'range_number' or columnsObj.filter_type == 'range_date'
            columnsObj.filter_default_label = [
              'from'
              'to'
            ]
          else if columnsObj.filter_type == 'date'
            columnsObj.filter_default_label = 'Select a date'
        columnsObj = $.extend({}, default_options, columnsObj)
        column_number_str = columnsArrayToString(columnsObj.column_number).column_number_str
        columnsObj.column_number_str = column_number_str
        dummyArr.push columnsObj
        tablesSelectors = ''
        i = 0
        while i < tablesArray.length
          if tablesArray[i].table?
            tablesSelectors += tablesArray[i].table().node().id + ','
          else
            tablesSelectors += getSettingsObjFromTable(tablesArray[i]).sTableId
          i++
        tablesSelectors = tablesSelectors.substring(0, tablesSelectors.length - 1)
        setOptions tablesSelectors + '_' + column_number_str, dummyArr
        oTables[tablesSelectors] = tablesArray
        appendFiltersMultipleTables tablesArray, tablesSelectors, columnsObj
        columnsArrIndex++
      return

    initMultipleColumns = (table, filtersOptions) ->
      tablesArray = []
      tablesArray.push table
      initMultipleTables tablesArray, filtersOptions
      return

    stopPropagation = (evt) ->
      if evt.stopPropagation?
        evt.stopPropagation()
      else
        evt.cancelBubble = true
      return

    preventDefaultForEnter = (evt) ->
      if evt.keyCode == 13
        if evt.preventDefault
          evt.preventDefault()
        else
          evt.returnValue = false
      return

    exInternalFilterColumnAJAXQueue = (table_arg, col_filter_arr) ->
      ->
        exFilterColumn table_arg, col_filter_arr, true
        return

    exFilterColumn = (table_arg, col_filter_arr, ajaxSource) ->
      table_selector_jq_friendly = undefined
      j = undefined
      tmpStr = undefined
      column_number = undefined
      column_position = undefined
      filter_value = undefined
      fromId = undefined
      toId = undefined
      sliderId = undefined
      optionsObj = undefined
      min = undefined
      max = undefined
      exclude = false
      #check if the table arg is from new datatables API (capital "D")
      if table_arg.settings?
        table_arg = table_arg.settings()[0].oInstance
      table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendly(table_arg.selector)
      if isDOMSource(table_arg) or ajaxSource == true
        j = 0
        while j < col_filter_arr.length
          column_number = col_filter_arr[j][0]
          column_position = column_number
          exclude = false
          if plugins[table_selector_jq_friendly]? and plugins[table_selector_jq_friendly]? and plugins[table_selector_jq_friendly].ColReorder?
            column_position = plugins[table_selector_jq_friendly].ColReorder[column_number]
          optionsObj = getOptions(table_arg.selector)[column_number]
          filter_value = col_filter_arr[j][1]
          switch optionsObj.filter_type
            when 'auto_complete', 'text', 'date'
              if filter_value? and filter_value.indexOf('_exclude_') != -1
                exclude = true
                filter_value = filter_value.replace('_exclude_', '')
              $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val filter_value
              if filter_value != ''
                $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).addClass 'inuse'
              else
                $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).removeClass 'inuse'
              tmpStr = yadcfMatchFilterString(table_arg, column_position, filter_value, optionsObj.filter_match_mode, false, exclude)
              table_arg.fnSettings().aoPreSearchCols[column_position].sSearch = tmpStr
            when 'select'
              $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val filter_value
              if filter_value != ''
                $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).addClass 'inuse'
              else
                $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).removeClass 'inuse'
              tmpStr = yadcfMatchFilterString(table_arg, column_position, filter_value, optionsObj.filter_match_mode, false)
              table_arg.fnSettings().aoPreSearchCols[column_position].sSearch = tmpStr
              if optionsObj.select_type?
                refreshSelectPlugin optionsObj, $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number), '-1'
            when 'multi_select'
              $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val filter_value
              tmpStr = yadcfMatchFilterString(table_arg, column_position, filter_value, optionsObj.filter_match_mode, true)
              table_arg.fnSettings().aoPreSearchCols[column_position].sSearch = tmpStr
              if optionsObj.select_type?
                refreshSelectPlugin optionsObj, $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number), '-1'
            when 'range_date'
              fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-from-date-' + column_number
              toId = 'yadcf-filter-' + table_selector_jq_friendly + '-to-date-' + column_number
              $('#' + fromId).val filter_value.from
              if filter_value.from != ''
                $('#' + fromId).addClass 'inuse'
              else
                $('#' + fromId).removeClass 'inuse'
              $('#' + toId).val filter_value.to
              if filter_value.to != ''
                $('#' + toId).addClass 'inuse'
              else
                $('#' + toId).removeClass 'inuse'
              if table_arg.fnSettings().oFeatures.bServerSide == true
                min = filter_value.from
                max = filter_value.to
                table_arg.fnSettings().aoPreSearchCols[column_position].sSearch = min + '-yadcf_delim-' + max
              saveStateSave table_arg, column_number, table_selector_jq_friendly, filter_value.from, filter_value.to
            when 'range_number'
              fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-from-' + column_number
              toId = 'yadcf-filter-' + table_selector_jq_friendly + '-to-' + column_number
              $('#' + fromId).val filter_value.from
              if filter_value.from != ''
                $('#' + fromId).addClass 'inuse'
              else
                $('#' + fromId).removeClass 'inuse'
              $('#' + toId).val filter_value.to
              if filter_value.to != ''
                $('#' + toId).addClass 'inuse'
              else
                $('#' + toId).removeClass 'inuse'
              if table_arg.fnSettings().oFeatures.bServerSide == true
                table_arg.fnSettings().aoPreSearchCols[column_position].sSearch = filter_value.from + '-yadcf_delim-' + filter_value.to
              saveStateSave table_arg, column_number, table_selector_jq_friendly, filter_value.from, filter_value.to
            when 'range_number_slider'
              sliderId = 'yadcf-filter-' + table_selector_jq_friendly + '-slider-' + column_number
              fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-min_tip-' + column_number
              toId = 'yadcf-filter-' + table_selector_jq_friendly + '-max_tip-' + column_number
              if filter_value.from != ''
                min = $('#' + fromId).closest('.yadcf-filter-range-number-slider').find('.yadcf-filter-range-number-slider-min-tip-hidden').text()
                max = $('#' + fromId).closest('.yadcf-filter-range-number-slider').find('.yadcf-filter-range-number-slider-max-tip-hidden').text()
                $('#' + fromId).text filter_value.from
                if min != filter_value.from
                  $('#' + fromId).parent().addClass 'inuse'
                  $('#' + fromId).parent().parent().find('ui-slider-range').addClass 'inuse'
                else
                  $('#' + fromId).parent().removeClass 'inuse'
                  $('#' + fromId).parent().parent().find('ui-slider-range').removeClass 'inuse'
                $('#' + sliderId).slider 'values', 0, filter_value.from
              if filter_value.to != ''
                $('#' + toId).text filter_value.to
                if max != filter_value.to
                  $('#' + toId).parent().addClass 'inuse'
                  $('#' + toId).parent().parent().find('.ui-slider-range').addClass 'inuse'
                else
                  $('#' + toId).parent().removeClass 'inuse'
                  $('#' + toId).parent().parent().find('.ui-slider-range').removeClass 'inuse'
                $('#' + sliderId).slider 'values', 1, filter_value.to
              if table_arg.fnSettings().oFeatures.bServerSide == true
                table_arg.fnSettings().aoPreSearchCols[column_position].sSearch = filter_value.from + '-yadcf_delim-' + filter_value.to
              saveStateSave table_arg, column_number, table_selector_jq_friendly, filter_value.from, filter_value.to
            when 'custom_func', 'multi_select_custom_func'
              $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).val filter_value
              if filter_value != ''
                $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).addClass 'inuse'
              else
                $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number).removeClass 'inuse'
              if table_arg.fnSettings().oFeatures.bServerSide == true
                table_arg.fnSettings().aoPreSearchCols[column_position].sSearch = filter_value
              if optionsObj.select_type?
                refreshSelectPlugin optionsObj, $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number), filter_value
              saveStateSave table_arg, column_number, table_selector_jq_friendly, filter_value, ''
          j++
        if table_arg.fnSettings().oFeatures.bServerSide != true
          table_arg.fnDraw()
        else
          setTimeout (->
            table_arg.fnDraw()
            return
          ), 10
      else
        exFilterColumnQueue.push exInternalFilterColumnAJAXQueue(table_arg, col_filter_arr)
      return

    exGetColumnFilterVal = (table_arg, column_number) ->
      retVal = undefined
      fromId = undefined
      toId = undefined
      table_selector_jq_friendly = undefined
      optionsObj = undefined
      $filterElement = undefined
      #check if the table arg is from new datatables API (capital "D")
      if table_arg.settings?
        table_arg = table_arg.settings()[0].oInstance
      optionsObj = getOptions(table_arg.selector)[column_number]
      table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendly(table_arg.selector)
      $filterElement = $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number)
      switch optionsObj.filter_type
        when 'select', 'custom_func'
          retVal = $filterElement.val()
          if retVal == '-1'
            retVal = ''
        when 'auto_complete', 'text', 'date'
          retVal = $filterElement.val()
          if $filterElement.prev().hasClass('yadcf-exclude-wrapper') and $filterElement.prev().find('input').prop('checked') == true
            retVal = '_exclude_' + retVal
        when 'multi_select'
          retVal = $filterElement.val()
          if retVal == null
            retVal = ''
        when 'range_date'
          retVal = {}
          fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-from-date-' + column_number
          toId = 'yadcf-filter-' + table_selector_jq_friendly + '-to-date-' + column_number
          retVal.from = $('#' + fromId).val()
          retVal.to = $('#' + toId).val()
        when 'range_number'
          retVal = {}
          fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-from-' + column_number
          toId = 'yadcf-filter-' + table_selector_jq_friendly + '-to-' + column_number
          retVal.from = $('#' + fromId).val()
          retVal.to = $('#' + toId).val()
        when 'range_number_slider'
          retVal = {}
          fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-min_tip-' + column_number
          toId = 'yadcf-filter-' + table_selector_jq_friendly + '-max_tip-' + column_number
          retVal.from = $('#' + fromId).text()
          retVal.to = $('#' + toId).text()
        else
          console.log 'exGetColumnFilterVal error: no such filter_type: ' + optionsObj.filter_type
      retVal

    clearStateSave = (oTable, column_number, table_selector_jq_friendly) ->
      yadcfState = undefined
      if oTable.fnSettings().oFeatures.bStateSave == true
        if !oTable.fnSettings().oLoadedState
          oTable.fnSettings().oLoadedState = {}
          oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
        if oTable.fnSettings().oLoadedState.yadcfState? and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly]?
          oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number] = undefined
        else
          yadcfState = {}
          yadcfState[table_selector_jq_friendly] = []
          yadcfState[table_selector_jq_friendly][column_number] = undefined
          oTable.fnSettings().oLoadedState.yadcfState = yadcfState
        oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
      return

    saveStateSave = (oTable, column_number, table_selector_jq_friendly, from, to) ->
      yadcfState = undefined
      if oTable.fnSettings().oFeatures.bStateSave == true
        if !oTable.fnSettings().oLoadedState
          oTable.fnSettings().oLoadedState = {}
        if oTable.fnSettings().oLoadedState.yadcfState? and oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly]?
          oTable.fnSettings().oLoadedState.yadcfState[table_selector_jq_friendly][column_number] =
            'from': from
            'to': to
        else
          yadcfState = {}
          yadcfState[table_selector_jq_friendly] = []
          yadcfState[table_selector_jq_friendly][column_number] =
            'from': from
            'to': to
          oTable.fnSettings().oLoadedState.yadcfState = yadcfState
        oTable.fnSettings().oApi._fnSaveState oTable.fnSettings()
      return

    exResetAllFilters = (table_arg, noRedraw, columns) ->
      table_selector_jq_friendly = undefined
      column_number = undefined
      fromId = undefined
      toId = undefined
      sliderId = undefined
      tableOptions = undefined
      optionsObj = undefined
      settingsDt = getSettingsObjFromTable(table_arg)
      i = undefined
      $filterElement = undefined

      # check if the table arg is from new datatables API (capital "D")
      if table_arg.settings?
        table_arg = table_arg.settings()[0].oInstance

      tableOptions = getOptions(table_arg.selector)
      table_selector_jq_friendly = yadcf.generateTableSelectorJQFriendly(table_arg.selector)
      settingsDt = getSettingsObjFromTable(table_arg)

      for columnObjKey of tableOptions
        if tableOptions.hasOwnProperty(columnObjKey)
          optionsObj = tableOptions[columnObjKey]
          column_number = optionsObj.column_number
          if columns? and $.inArray(column_number, columns) == -1
            # j++
            continue

          $(document).removeData '#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val'
          $filterElement = $('#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number)
          switch optionsObj.filter_type
            when 'select', 'custom_func'
              $filterElement.val('-1').removeClass 'inuse'
              table_arg.fnSettings().aoPreSearchCols[column_number].sSearch = ''
              if optionsObj.select_type?
                refreshSelectPlugin optionsObj, $filterElement, '-1'
            when 'auto_complete', 'text', 'date'
              $filterElement.val('').removeClass 'inuse'
              table_arg.fnSettings().aoPreSearchCols[column_number].sSearch = ''
              if $filterElement.prev().hasClass('yadcf-exclude-wrapper')
                $filterElement.prev().find('input').prop 'checked', false
            when 'multi_select', 'multi_select_custom_func'
              $filterElement.val '-1'
              $(document).data '#yadcf-filter-' + table_selector_jq_friendly + '-' + column_number + '_val', undefined
              table_arg.fnSettings().aoPreSearchCols[column_number].sSearch = ''
              if optionsObj.select_type?
                refreshSelectPlugin optionsObj, $filterElement, '-1'
            when 'range_date'
              fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-from-date-' + column_number
              toId = 'yadcf-filter-' + table_selector_jq_friendly + '-to-date-' + column_number
              $('#' + fromId).val ''
              $('#' + fromId).removeClass 'inuse'
              $('#' + toId).val ''
              $('#' + toId).removeClass 'inuse'
              if table_arg.fnSettings().oFeatures.bServerSide == true
                table_arg.fnSettings().aoPreSearchCols[column_number].sSearch = ''
              clearStateSave table_arg, column_number, table_selector_jq_friendly
            when 'range_number'
              fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-from-' + column_number
              toId = 'yadcf-filter-' + table_selector_jq_friendly + '-to-' + column_number
              $('#' + fromId).val ''
              $('#' + fromId).removeClass 'inuse'
              $('#' + toId).val ''
              $('#' + toId).removeClass 'inuse'
              if table_arg.fnSettings().oFeatures.bServerSide == true
                table_arg.fnSettings().aoPreSearchCols[column_number].sSearch = ''
              clearStateSave table_arg, column_number, table_selector_jq_friendly
            when 'range_number_slider'
              sliderId = 'yadcf-filter-' + table_selector_jq_friendly + '-slider-' + column_number
              fromId = 'yadcf-filter-' + table_selector_jq_friendly + '-min_tip-' + column_number
              toId = 'yadcf-filter-' + table_selector_jq_friendly + '-max_tip-' + column_number
              $('#' + fromId).text ''
              $('#' + fromId).parent().removeClass 'inuse'
              $('#' + fromId).parent().parent().find('ui-slider-range').removeClass 'inuse'
              $('#' + toId).text ''
              $('#' + toId).parent().removeClass 'inuse'
              $('#' + toId).parent().parent().find('.ui-slider-range').removeClass 'inuse'
              $('#' + sliderId).slider 'option', 'values', [
                $('#' + fromId).parent().parent().find('.yadcf-filter-range-number-slider-min-tip-hidden').text()
                $('#' + fromId).parent().parent().find('.yadcf-filter-range-number-slider-max-tip-hidden').text()
              ]
              if table_arg.fnSettings().oFeatures.bServerSide == true
                table_arg.fnSettings().aoPreSearchCols[column_number].sSearch = ''
              clearStateSave table_arg, column_number, table_selector_jq_friendly

      if noRedraw != true
        # clear global filter
        settingsDt.oPreviousSearch.sSearch = ''
        if settingsDt.aanFeatures.f?
          i = 0
          while i < settingsDt.aanFeatures.f.length
            $('input', settingsDt.aanFeatures.f[i]).val ''
            i++
        # end of clear global filter
        table_arg.fnDraw settingsDt
      return

    exResetFilters = (table_arg, columns, noRedraw) ->
      exResetAllFilters table_arg, noRedraw, columns
      return

    exFilterExternallyTriggered = (table_arg) ->
      columnsObj = undefined
      columnObj = undefined
      filterValue = undefined
      filtersValuesSingleElem = undefined
      filtersValuesArr = []
      #check if the table arg is from new datatables API (capital "D")
      if table_arg.settings?
        table_arg = table_arg.settings()[0].oInstance
      columnsObj = getOptions(table_arg.selector)
      for columnObjKey of columnsObj
        if columnsObj.hasOwnProperty(columnObjKey)
          columnObj = columnsObj[columnObjKey]
          filterValue = exGetColumnFilterVal(table_arg, columnObj.column_number)
          filtersValuesSingleElem = []
          filtersValuesSingleElem.push columnObj.column_number
          filtersValuesSingleElem.push filterValue
          filtersValuesArr.push filtersValuesSingleElem
      exFilterColumn table_arg, filtersValuesArr, true
      return

    yadcfDelay = do ->
      timer = 0
      (callback, ms, param) ->
        clearTimeout timer
        timer = setTimeout((->
          callback param
          return
        ), ms)
        timer

    $.fn.yadcf = (options_arg, params) ->
      tmpParams = undefined
      i = 0
      selector = undefined
      tableSelector = '#' + @fnSettings().sTableId
      # in case that instance.selector will be undefined (jQuery 3)
      if @selector == undefined
        @selector = tableSelector
      if params == undefined
        params = {}
      if typeof params == 'string'
        tmpParams = params
        params = {}
        params.filters_position = tmpParams
      if params.filters_position == undefined or params.filters_position == 'header'
        params.filters_position = 'thead'
      else
        params.filters_position = 'tfoot'
      $(document).data @selector + '_filters_position', params.filters_position
      if $(@selector).length == 1
        setOptions @selector, options_arg, params
        initAndBindTable this, @selector, 0
      else
        i
        while i < $(@selector).length
          $.fn.dataTableExt.iApiIndex = i
          selector = @selector + ':eq(' + i + ')'
          setOptions @selector, options_arg, params
          initAndBindTable this, selector, i
          i++
        $.fn.dataTableExt.iApiIndex = 0
      this

    {
      init: init
      doFilter: doFilter
      doFilterMultiSelect: doFilterMultiSelect
      doFilterAutocomplete: doFilterAutocomplete
      autocompleteKeyUP: autocompleteKeyUP
      getOptions: getOptions
      rangeNumberKeyUP: rangeNumberKeyUP
      rangeDateKeyUP: rangeDateKeyUP
      rangeClear: rangeClear
      rangeNumberSliderClear: rangeNumberSliderClear
      stopPropagation: stopPropagation
      generateTableSelectorJQFriendly: generateTableSelectorJQFriendly
      exFilterColumn: exFilterColumn
      exGetColumnFilterVal: exGetColumnFilterVal
      exResetAllFilters: exResetAllFilters
      dateKeyUP: dateKeyUP
      dateSelectSingle: dateSelectSingle
      textKeyUP: textKeyUP
      doFilterCustomDateFunc: doFilterCustomDateFunc
      eventTargetFixUp: eventTargetFixUp
      initMultipleTables: initMultipleTables
      initMultipleColumns: initMultipleColumns
      textKeyUpMultiTables: textKeyUpMultiTables
      doFilterMultiTables: doFilterMultiTables
      doFilterMultiTablesMultiSelect: doFilterMultiTablesMultiSelect
      generateTableSelectorJQFriendlyNew: generateTableSelectorJQFriendlyNew
      exFilterExternallyTriggered: exFilterExternallyTriggered
      exResetFilters: exResetFilters
      initSelectPluginCustomTriggers: initSelectPluginCustomTriggers
      preventDefaultForEnter: preventDefaultForEnter
    }
  if window
    window.yadcf = yadcf
  yadcf
