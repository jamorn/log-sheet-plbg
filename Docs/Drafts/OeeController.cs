// Controllers/OeeController.cs
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace BackendAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class OeeController : ControllerBase
    {
        private readonly IOeeService _oeeService;
        private readonly IMachineService _machineService;
        private readonly ILogger<OeeController> _logger;

        public OeeController(
            IOeeService oeeService, 
            IMachineService machineService,
            ILogger<OeeController> logger)
        {
            _oeeService = oeeService;
            _machineService = machineService;
            _logger = logger;
        }

        [HttpGet("summary")]
        public async Task<IActionResult> GetOeeSummary(
            [FromQuery] DateTime shiftDate,
            [FromQuery] int? machineId = null,
            [FromQuery] int? unitId = null,
            [FromQuery] string timeRange = "daily")
        {
            try
            {
                var results = await _oeeService.GetOeeSummaryAsync(
                    shiftDate, 
                    machineId, 
                    unitId, 
                    timeRange);
                
                return Ok(results);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting OEE summary");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpPost("calculate")]
        public async Task<IActionResult> CalculateOee([FromBody] CalculateOeeRequest request)
        {
            try
            {
                var result = await _oeeService.CalculateDailyOeeAsync(
                    request.ShiftDate, 
                    request.MachineId, 
                    request.Recalculate);
                
                return Ok(new { 
                    success = true, 
                    message = "OEE calculated successfully",
                    data = result 
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error calculating OEE");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpGet("export")]
        public async Task<IActionResult> ExportOeeReport(
            [FromQuery] DateTime startDate,
            [FromQuery] DateTime endDate,
            [FromQuery] string format = "excel")
        {
            try
            {
                var reportData = await _oeeService.GenerateOeeReportAsync(startDate, endDate);
                
                if (format.ToLower() == "excel")
                {
                    var excelBytes = ExportToExcel(reportData);
                    return File(excelBytes, 
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", 
                        $"OEE_Report_{startDate:yyyyMMdd}_{endDate:yyyyMMdd}.xlsx");
                }
                
                return Ok(reportData);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error exporting OEE report");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpGet("machines/active")]
        public async Task<IActionResult> GetActiveMachines()
        {
            try
            {
                var machines = await _machineService.GetActiveMachinesAsync();
                return Ok(machines);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting active machines");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpGet("loss-categories/active")]
        public async Task<IActionResult> GetActiveLossCategories()
        {
            try
            {
                var categories = await _oeeService.GetLossCategoriesAsync();
                return Ok(categories);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting loss categories");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        private byte[] ExportToExcel(List<OeeSummaryDto> data)
        {
            // Implement Excel export using EPPlus or ClosedXML
            // Return Excel file bytes
            return new byte[0];
        }
    }

    public class CalculateOeeRequest
    {
        public DateTime ShiftDate { get; set; }
        public int MachineId { get; set; }
        public bool Recalculate { get; set; }
    }
}