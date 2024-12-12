<svelte:options customElement="ps-export-excel" />
<script>
  import * as XLSX from 'xlsx';

  /** @type {string} */
  let {
    filename = 'exported_data.xlsx',
    formSelector = 'form.noSubmitLoading',
    debug = false
  } = $props();

  let isLoading = $state(false);
  let error = $state(null);
  let selectedFormat = $state(getStoredFormat());
  let showDropdown = $state(false);

  function getStoredFormat() {
    if (typeof localStorage !== 'undefined') {
      return localStorage.getItem('ps-export-excel-format') || 'xlsx';
    }
    return 'xlsx';
  }

  function setStoredFormat(format) {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('ps-export-excel-format', format);
    }
  }

  function debugLog(message, data) {
    if (!debug) return;
    if (data === undefined) {
      console.log(`[ExportToExcel] ${message}`);
    } else {
      console.log(`[ExportToExcel] ${message}:`, data);
    }
  }

  async function fetchData(url) {
    const response = await fetch(url);
    if (!response.ok) {
      if (response.status === 404) {
        throw new Error('The requested data could not be found. Please check the endpoint URL.');
      }
      throw new Error(`Failed to fetch data (${response.status})`); 
    }
    return response.text();
  }

  function processData(textData) {
    if (!textData.trim()) {
      throw new Error('Server returned empty response');
    }

    debugLog('Received text data', textData.substring(0, 100) + '...');

    // Parse the text data (assuming tab-separated values)
    const workbook = XLSX.read(textData, { type: "string", raw: true });
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 0 });

    // Process the data
    return jsonData.map(row => {
      const newRow = {};
      for (const [key, value] of Object.entries(row)) {
        newRow[key] = formatDate(value);
      }
      return newRow;
    });
  }

  function formatDate(value) {
    // Check if the value matches the pattern YYYY-MM-DDT00:00:00
    const datePattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/;
    if (typeof value === 'string' && datePattern.test(value)) {
      const date = new Date(value);
      return `${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getDate().toString().padStart(2, '0')}/${date.getFullYear()}`;
    }
    return value;
  }

  function getFileExtension() {
    switch (selectedFormat) {
      case 'csv':
        return '.csv';
      case 'txt':
        return '.txt';
      default:
        return '.xlsx';
    }
  }

  function selectFormat(format) {
    selectedFormat = format;
    setStoredFormat(format);
    showDropdown = false;
  }

  function toggleDropdown(event) {
    event.stopPropagation();
    showDropdown = !showDropdown;
  }

  function handleClickOutside(event) {
    if (showDropdown && !event.target.closest('.format-selector')) {
      showDropdown = false;
    }
  }

  function handleExport(event) {
    event.preventDefault();
    isLoading = true;
    error = null;

    try {
      const form = document.querySelector(formSelector);
      if (!form) {
        throw new Error('Form not found');
      }

      const formData = new FormData(form);
      const url = form.action + '?' + new URLSearchParams(formData).toString();

      debugLog('Fetching data from URL', url);

      fetchData(url)
      .then(textData => {
        const processedData = processData(textData);
        debugLog('Processed data', processedData);

        const newWorkbook = XLSX.utils.book_new();
        const newWorksheet = XLSX.utils.json_to_sheet(processedData);

        // Apply styles and freeze pane
        styleWorksheet(newWorksheet);

        XLSX.utils.book_append_sheet(newWorkbook, newWorksheet, "Sheet1");

        // Get base filename without extension
        const baseName = filename.replace(/\.[^/.]+$/, "");
        const exportFilename = baseName + getFileExtension();

        // Export based on selected format
        switch (selectedFormat) {
          case 'csv':
            XLSX.writeFile(newWorkbook, exportFilename, { bookType: 'csv' });
            break;
          case 'txt':
            XLSX.writeFile(newWorkbook, exportFilename, { bookType: 'txt' });
            break;
          default:
            XLSX.writeFile(newWorkbook, exportFilename);
        }

        debugLog('Excel file created', exportFilename);
      })
      .catch(error => {
        console.error('[ExportToExcel] Export error:', error);
        this.error = error instanceof Error ? error.message : 'Failed to export data';
      })
      .finally(() => {
        isLoading = false;
      });

    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to export data';
      console.error('[ExportToExcel] Export error:', e);
      isLoading = false;
    }
  }

  function styleWorksheet(worksheet) {
    // Freeze the top row using sheetViews
    worksheet['!sheetViews'] = [
      {
        state: 'frozen',
        ySplit: 1, 
        xSplit: 0, // Optional: If you want to freeze the first column as well
        topLeftCell: 'B2', // Optional, but recommended for consistency
        activePane: 'bottomRight' // Optional, but recommended for consistency
      }
    ];

    // Enable filtering
    // worksheet['!autofilter'] = { ref: worksheet['!ref'] };
    
    // Make header row bold and auto-size columns
    const range = XLSX.utils.decode_range(worksheet['!ref']);
    const colWidths = [];
    for (let C = range.s.c; C <= range.e.c; ++C) {
      let maxLen = 0;
      for (let R = range.s.r; R <= range.e.r; ++R) {
        const cell = worksheet[XLSX.utils.encode_cell({ r: R, c: C })];
        if (cell && cell.v) {
          const cellLen = String(cell.v).length;
          maxLen = Math.max(maxLen, cellLen);
        }
        // Make header bold
        if (R === 0) {
          const header = XLSX.utils.encode_cell({ r: 0, c: C });
          if (worksheet[header]) {
            worksheet[header].s = { font: { bold: true } };
          }
        }
      }
      colWidths[C] = maxLen + 2; // Add padding
    }
    worksheet['!cols'] = colWidths.map(w => ({ wch: w }));
  }
</script>

<div class="button-container format-selector">
  <button 
    class="main-button"
    onclick={handleExport}
    disabled={isLoading} 
    class:loading={isLoading}
    aria-busy={isLoading}
  >
    <slot>
      {#if isLoading}
        Exporting...
      {:else}
        Export to {selectedFormat}
      {/if}
    </slot>
  </button>
  <button
    class="dropdown-toggle"
    onclick={toggleDropdown}
    disabled={isLoading}
    aria-label="Select export format"
  >
    <span class="caret-down"></span>
  </button>
  {#if showDropdown}
    <div class="dropdown-content">
      <button class="dropdown-item" onclick={() => selectFormat('xlsx')}>Excel (.xlsx)</button>
      <button class="dropdown-item" onclick={() => selectFormat('csv')}>CSV (.csv)</button>
      <button class="dropdown-item" onclick={() => selectFormat('txt')}>Text (.txt)</button>
    </div>
  {/if}
</div>

{#if error}
  <div class="error" role="alert">
    {error}
  </div>
{/if}

<style>
  .button-container {
    display: inline-flex;
    position: relative;
  }

  button {
    padding: 6px 12px;
    background-color: var(--primary-color, #4CAF50);
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 14px;
    line-height: 1.42857143;
    transition: background-color 0.2s, opacity 0.2s;
    height: 32px;
  }

  .main-button {
    border-top-right-radius: 0;
    border-bottom-right-radius: 0;
    border-right: 1px solid rgba(255, 255, 255, 0.2);
    flex: 3;
    white-space: nowrap;
  }

  .dropdown-toggle {
    padding: 8px 10px;
    border-top-left-radius: 0;
    border-bottom-left-radius: 0;
    flex: 1;
  }

  .dropdown-content {
    position: absolute;
    top: 100%;
    right: 0;
    background-color: white;
    border: 1px solid #ddd;
    border-radius: 4px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    z-index: 1000;
    min-width: 120px;
    margin-top: 4px;
  }

  .dropdown-item {
    padding: 8px 12px;
    cursor: pointer;
    color: #333;
    display: block;
    text-align: left;
    border: none;
    width: 100%;
    background: none;
  }

  .dropdown-item:hover {
    background-color: #f5f5f5;
  }

  .caret-down {
    display: inline-block;
    width: 0;
    height: 0;
    border-left: 4px solid transparent;
    border-right: 4px solid transparent;
    border-top: 4px solid currentColor;
    margin-left: 4px;
  }

  .error {
    color: var(--error-color, #dc3545);
    font-size: 14px;
    margin-top: 8px;
  }

  .loading {
    position: relative;
    padding-right: 2em; /* Make room for the spinner */
  }

  .loading::after {
    content: '';
    position: absolute;
    width: 1em;
    height: 1em;
    border: 2px solid transparent;
    border-top-color: currentColor;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
    margin-left: 8px;
    top: 50%;
    transform: translateY(-50%);
  }

  @keyframes spin {
    to {
      transform: translateY(-50%) rotate(360deg);
    }
  }
</style>