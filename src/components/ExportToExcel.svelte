<svelte:options customElement="ps-export-excel" />

<script>
  import * as XLSX from 'xlsx';
  import { onMount } from 'svelte';

  /** @type {string} */
  let { 
    endpoint = '/admin/importexport/is-apps/export.json',
    filename = 'export.xlsx',
    textareaId = 'tt',  // ID of the textarea containing the fields
    debug = false       // Debug flag
  } = $props();

  /** @type {boolean} */
  let isLoading = $state(false);
  
  /** @type {string | null} */
  let error = $state(null);

  function debugLog(message, data) {
    if (!debug) return;
    if (data === undefined) {
      console.log(`[ExportToExcel] ${message}`);
    } else {
      console.log(`[ExportToExcel] ${message}:`, data);
    }
  }

  async function exportToExcel() {
    isLoading = true;
    error = null;
    
    try {
      // Get selected fields from textarea
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

      // Build the URL with fields parameter
      const url = new URL(endpoint, window.location.origin);
      url.searchParams.set('fields', fields.join(','));
      debugLog('Request URL', url.toString());

      const response = await fetch(url);
      debugLog('Response status', response.status);
      
      if (!response.ok) {
        throw new Error(`Failed to fetch data (${response.status})`);
      }

      const rawText = await response.text();
      if (!rawText.trim()) {
        throw new Error('Server returned empty response');
      }
      debugLog('Raw response', rawText);

      let jsonData;
      try {
        jsonData = JSON.parse(rawText);
      } catch (parseError) {
        throw new Error(`Invalid JSON response: ${parseError.message}\nRaw response: ${rawText.substring(0, 100)}...`);
      }

      if (!Array.isArray(jsonData) && typeof jsonData !== 'object') {
        throw new Error('Expected JSON array or object, got: ' + typeof jsonData);
      }

      const dataArray = Array.isArray(jsonData) ? jsonData : [jsonData];
      debugLog('Processed data rows', dataArray.length);
      
      const workbook = XLSX.utils.book_new();
      const worksheet = XLSX.utils.json_to_sheet(dataArray);
      
      // Enable filtering
      worksheet['!autofilter'] = { ref: worksheet['!ref'] };
      
      // Freeze the header row
      worksheet['!freeze'] = { xSplit: 0, ySplit: 1 };
      
      // Make header row bold
      const range = XLSX.utils.decode_range(worksheet['!ref']);
      for (let C = range.s.c; C <= range.e.c; ++C) {
        const header = XLSX.utils.encode_cell({ r: 0, c: C });
        if (!worksheet[header]) continue;
        worksheet[header].s = { font: { bold: true } };
      }
      
      // Auto-size columns
      const colWidths = [];
      for (let C = range.s.c; C <= range.e.c; ++C) {
        let maxLen = 0;
        for (let R = range.s.r; R <= range.e.r; ++R) {
          const cell = worksheet[XLSX.utils.encode_cell({ r: R, c: C })];
          if (cell && cell.v) {
            const cellLen = String(cell.v).length;
            maxLen = Math.max(maxLen, cellLen);
          }
        }
        colWidths[C] = maxLen + 2; // Add padding
      }
      worksheet['!cols'] = colWidths.map(w => ({ wch: w }));

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