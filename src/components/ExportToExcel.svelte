<svelte:options customElement="ps-export-excel" />
<script>
  import * as XLSX from 'xlsx';

  /** @type {string} */
  let { 
    endpoint = '/admin/importexport/is-apps/export.json',
    filename = 'export.xlsx',
    textareaId = 'tt', 
    debug = false       
  } = $props();

  let isLoading = $state(false);
  let error = $state(null);

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
    const rawText = await response.text();
    if (!rawText.trim()) {
      throw new Error('Server returned empty response');
    }
    return JSON.parse(rawText); 
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

  function formatDate(value) {
    // Check if the value matches the pattern YYYY-MM-DDT00:00:00
    const datePattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/;
    if (typeof value === 'string' && datePattern.test(value)) {
      const date = new Date(value);
      return `${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getDate().toString().padStart(2, '0')}/${date.getFullYear()}`;
    }
    return value;
  }

  function processData(data) {
    return data.map(row => {
      const newRow = {};
      for (const [key, value] of Object.entries(row)) {
        newRow[key] = formatDate(value);
      }
      return newRow;
    });
  }

  async function exportToExcel() {
    isLoading = true;
    error = null;

    try {
      const textarea = document.getElementById(textareaId);
      if (!textarea) {
        throw new Error(`Could not find textarea with ID: ${textareaId}`);
      }

      const textareaValue = textarea.value.trim();
      debugLog('Textarea value', textareaValue);
      
      if (!textareaValue) {
        throw new Error('Please select fields to export');
      }

      const fields = textareaValue.split('\n').filter(field => field.trim());
      debugLog('Found fields', fields);

      if (!fields.length) {
        throw new Error('No valid fields selected for export');
      }

      const url = new URL(endpoint, window.location.origin);
      url.searchParams.set('fields', fields.join(','));
      debugLog('Request URL', url.toString());

      let jsonData = await fetchData(url); 

      // Handle empty data
      if (!jsonData || (Array.isArray(jsonData) && jsonData.length === 0)) {
        alert('No data found to export.'); 
        return;
      }

      const dataArray = Array.isArray(jsonData) ? jsonData : [jsonData];
      const processedData = processData(dataArray);
      debugLog('Processed data rows', processedData.length);

      const workbook = XLSX.utils.book_new();
      const worksheet = XLSX.utils.json_to_sheet(processedData);
      
      // Apply styles and freeze pane
      styleWorksheet(worksheet); 

      XLSX.utils.book_append_sheet(workbook, worksheet, "Sheet1");
      XLSX.writeFile(workbook, filename);
      debugLog('Excel file created', filename);

    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to export data';
      console.error('[ExportToExcel] Export error:', e);
    } finally {
      isLoading = false;
    }
  }
</script>

<button 
  onclick={exportToExcel} 
  disabled={isLoading} 
  class:loading={isLoading}
  aria-busy={isLoading}
>
  <slot>
    {#if isLoading}
      Exporting...
    {:else}
      Export to Excel
    {/if}
  </slot>
</button>

{#if error}
  <div class="error" role="alert">
    {error}
  </div>
{/if}

<style>
  button {
    padding: 8px 16px;
    background-color: var(--primary-color, #4CAF50);
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 14px;
    transition: background-color 0.2s, opacity 0.2s;
  }

  button:hover:not(:disabled) {
    background-color: var(--primary-color-dark, #45a049);
  }

  button:disabled {
    opacity: 0.7;
    cursor: not-allowed;
  }

  .error {
    color: var(--error-color, #dc3545);
    font-size: 14px;
    margin-top: 8px;
  }

  .loading {
    position: relative;
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
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>