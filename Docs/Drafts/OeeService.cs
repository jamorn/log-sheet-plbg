// Services/OeeService.cs
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Dapper;

namespace BackendAPI.Services
{
    public interface IOeeService
    {
        Task<List<OeeSummaryDto>> GetOeeSummaryAsync(
            DateTime shiftDate, 
            int? machineId = null, 
            int? unitId = null, 
            string timeRange = "daily");
        
        Task<OeeCalculationResult> CalculateDailyOeeAsync(
            DateTime shiftDate, 
            int machineId, 
            bool recalculate = false);
        
        Task<List<LossCategoryDto>> GetLossCategoriesAsync();
        Task<List<OeeReportDto>> GenerateOeeReportAsync(DateTime startDate, DateTime endDate);
    }

    public class OeeService : IOeeService
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly ILogger<OeeService> _logger;

        public OeeService(
            AppDbContext context, 
            IConfiguration configuration,
            ILogger<OeeService> logger)
        {
            _context = context;
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<List<OeeSummaryDto>> GetOeeSummaryAsync(
            DateTime shiftDate, 
            int? machineId = null, 
            int? unitId = null, 
            string timeRange = "daily")
        {
            var query = @"
                SELECT 
                    ds.ShiftDate,
                    ds.MachineID,
                    m.MachineName,
                    u.UnitName,
                    ds.Target_OEE_Pct as TargetOEE,
                    ds.Availability_Pct as Availability,
                    ds.Performance_Pct as Performance,
                    ds.Quality_Pct as Quality,
                    ds.OEE_Percentage as OEE,
                    ds.OEE_TargetMet,
                    ds.TotalTimeMin,
                    ds.OperatingTimeMin,
                    ds.ActualOutputMT,
                    ds.GoodBags,
                    ds.WasteBags,
                    ds.Top_Downtime_Reason as TopDowntimeReason,
                    ds.LastCalculated
                FROM DailyProductionSummary ds
                INNER JOIN Machines m ON ds.MachineID = m.MachineId
                INNER JOIN UnitPLBG u ON ds.UnitId = u.UnitId
                WHERE ds.ShiftDate = @ShiftDate
                    AND (@MachineId IS NULL OR ds.MachineID = @MachineId)
                    AND (@UnitId IS NULL OR ds.UnitId = @UnitId)
                ORDER BY m.MachineName";

            using var connection = new SqlConnection(_configuration.GetConnectionString("DefaultConnection"));
            
            var results = await connection.QueryAsync<OeeSummaryDto>(query, new {
                ShiftDate = shiftDate,
                MachineId = machineId,
                UnitId = unitId
            });

            return results.ToList();
        }

        public async Task<OeeCalculationResult> CalculateDailyOeeAsync(
            DateTime shiftDate, 
            int machineId, 
            bool recalculate = false)
        {
            using var connection = new SqlConnection(_configuration.GetConnectionString("DefaultConnection"));
            
            // Call stored procedure
            var result = await connection.QueryFirstOrDefaultAsync<OeeCalculationResult>(
                "EXEC CalculateDailyOeeSummary @ShiftDate, @MachineId",
                new { ShiftDate = shiftDate, MachineId = machineId });
            
            return result;
        }

        public async Task<List<LossCategoryDto>> GetLossCategoriesAsync()
        {
            var categories = await _context.DowntimeCategories
                .Include(dc => dc.OeeLossTypes)
                .Where(dc => dc.IsActive)
                .Select(dc => new LossCategoryDto
                {
                    CategoryId = dc.CategoryID,
                    CategoryNameTH = dc.CategoryNameTH,
                    CategoryLevel = dc.CategoryLevel,
                    LossTypes = dc.OeeLossTypes
                        .Where(olt => olt.IsActive)
                        .OrderBy(olt => olt.DisplayOrder)
                        .Select(olt => new LossTypeDto
                        {
                            ProblemTypeId = olt.ProblemTypeID,
                            TypeNameTH = olt.TypeNameTH,
                            DisplayOrder = olt.DisplayOrder,
                            IsActive = olt.IsActive
                        })
                        .ToList()
                })
                .OrderBy(dc => dc.CategoryLevel)
                .ToListAsync();

            return categories;
        }
    }

    // DTOs
    public class OeeSummaryDto
    {
        public DateTime ShiftDate { get; set; }
        public int MachineId { get; set; }
        public string MachineName { get; set; }
        public string UnitName { get; set; }
        public decimal TargetOEE { get; set; }
        public decimal Availability { get; set; }
        public decimal Performance { get; set; }
        public decimal Quality { get; set; }
        public decimal OEE { get; set; }
        public bool OeeTargetMet { get; set; }
        public int TotalTimeMin { get; set; }
        public decimal OperatingTimeMin { get; set; }
        public decimal ActualOutputMT { get; set; }
        public int GoodBags { get; set; }
        public int WasteBags { get; set; }
        public string TopDowntimeReason { get; set; }
        public DateTime LastCalculated { get; set; }
    }

    public class LossCategoryDto
    {
        public int CategoryId { get; set; }
        public string CategoryNameTH { get; set; }
        public int CategoryLevel { get; set; }
        public List<LossTypeDto> LossTypes { get; set; }
    }

    public class LossTypeDto
    {
        public int ProblemTypeId { get; set; }
        public string TypeNameTH { get; set; }
        public int DisplayOrder { get; set; }
        public bool IsActive { get; set; }
    }
}