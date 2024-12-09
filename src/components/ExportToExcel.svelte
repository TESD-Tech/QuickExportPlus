<svelte:options customElement="ps-export-excel" />
<script>
  import * as XLSX from 'xlsx';

  /** @type {string} */
  let {
    filename = 'student_data.xlsx',
    formSelector = 'form.noSubmitLoading',
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

  function handleExport(event) {
    event.preventDefault();
    isLoading = true;
    error = null;

    try {
      const form = document.querySelector(formSelector);
      if (!form) {
        throw new Error(`Could not find form with selector: ${formSelector}`);
      }

      // Create a new FormData object from the form
      const formData = new FormData(form);

      // Convert FormData to a plain object for easier logging
      const plainFormData = {};
      formData.forEach((value, key) => {
        plainFormData[key] = value;
      });

      debugLog('Form Data:', plainFormData);

      // Use fetch to make the same request as the form
      fetch(form.action, {
        method: form.method,
        body: formData,
        credentials: 'include'
      })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.text();
      })
      .then(textData => {
        if (!textData.trim()) {
          throw new Error('Server returned empty response');
        }

        debugLog('Received text data', textData.substring(0, 100) + '...');

        // Parse the text data (assuming tab-separated values)
        const workbook = XLSX.read(textData, { type: "string", raw: true });
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];
        const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 0 });

        // Remove the zero-indexed row if it exists
        if (jsonData.length > 0 && jsonData[0].length > 0 && jsonData[0][0] === '0') {
          // Remove the first column from each row
          jsonData.forEach(row => row.shift());
        }

        const processedData = processData(jsonData);
        debugLog('Processed data rows', processedData.length);

        const newWorkbook = XLSX.utils.book_new();
        const newWorksheet = XLSX.utils.json_to_sheet(processedData);

        // Apply styles and freeze pane
        styleWorksheet(newWorksheet);

        XLSX.utils.book_append_sheet(newWorkbook, newWorksheet, "Sheet1");
        XLSX.writeFile(newWorkbook, filename);
        debugLog('Excel file created', filename);
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
</script>

<form id="exportForm">
  <button 
    onclick={handleExport}
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
</form>

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