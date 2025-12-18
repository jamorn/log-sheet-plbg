using BackendAPI.Data;
using BackendAPI.DTOs;
using BackendAPI.Models;
using BackendAPI.Services.Interfaces;
using BackendAPI.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.DirectoryServices.AccountManagement;
using System.DirectoryServices;
using System.Runtime.Versioning;

namespace BackendAPI.Services
{
    public class AuthService : IAuthService
    {
        private readonly AppDbContext _context;
        private readonly ILogger<AuthService> _logger;
        private readonly IConfiguration _configuration;

        public AuthService(
            AppDbContext context, 
            ILogger<AuthService> logger,
            IConfiguration configuration)
        {
            _context = context;
            _logger = logger;
            _configuration = configuration;
        }

        /// <summary>
        /// สำหรับ Development Mode: อ่านข้อมูลจาก mock_user.json
        /// </summary>
        public async Task<AuthResponseDto> GetMockUserAsync(string? testUserType = null)
        {
            try
            {
                string mockPath = Path.Combine(Directory.GetCurrentDirectory(), "Mock", "mock_user.json");
                if (!File.Exists(mockPath))
                {
                    _logger.LogWarning($"Mock user file not found: {mockPath}");
                    return CreateUnauthenticatedResponse();
                }

                string json = await File.ReadAllTextAsync(mockPath);
                var mockResponse = System.Text.Json.JsonSerializer.Deserialize<AuthResponseDto>(json, new System.Text.Json.JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                if (mockResponse == null)
                {
                    return CreateUnauthenticatedResponse("Cannot deserialize mock user");
                }

                // ถ้ามีการระบุ user type ให้เลือกจาก dictionary
                if (!string.IsNullOrEmpty(testUserType))
                {
                    var testUsers = new Dictionary<string, (string Email, string Role, string Unit)>
                    {
                        ["admin"] = ("kittithuch.u@irpc.co.th", "admin", "PL"),
                        ["user"] = ("weerachai.in@irpc.co.th", "user", "PL"),
                        ["super"] = ("nirut.p@irpc.co.th", "super user", "PL")
                    };

                    if (testUsers.TryGetValue(testUserType, out var userInfo))
                    {
                        mockResponse.User = new UserDto
                        {
                            Email = userInfo.Email,
                            Role = userInfo.Role,
                            Unit = userInfo.Unit
                        };
                        mockResponse.Success = true;
                    }
                }

                return mockResponse;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error reading mock user");
                return CreateUnauthenticatedResponse(ex.Message);
            }
        }

        /// <summary>
        /// ดึงข้อมูลผู้ใช้ปัจจุบันจาก Windows Identity
        /// </summary>
        [SupportedOSPlatform("windows")]
        public async Task<AuthResponseDto> GetCurrentUserAsync(string? windowsIdentity)
        {
            // ถ้าเป็น development mode และมี header X-Test-User
            if (_configuration.GetValue<bool>("EnableTestUsers", false))
            {
                return await GetMockUserAsync();
            }

            try
            {
                _logger.LogInformation("[AuthService] Windows Identity: {Identity}", windowsIdentity);

                if (string.IsNullOrEmpty(windowsIdentity))
                {
                    return CreateUnauthenticatedResponse("Not authenticated");
                }

                // แยก domain และ username
                var (domain, username) = ParseWindowsIdentity(windowsIdentity);
                
                // 1. ตรวจสอบใน EmployeeDetails (ตารางใหม่สำหรับระบบ OEE)
                var oeeEmployee = await _context.EmployeeDetails
                    .Include(e => e.CostCenter)
                    .Include(e => e.DefaultMachine)
                    .FirstOrDefaultAsync(e => e.WindowsLogin == windowsIdentity && e.IsAllowed);

                if (oeeEmployee != null)
                {
                    _logger.LogInformation("[AuthService] Found in EmployeeDetails: {Name}", oeeEmployee.DisplayName);
                    
                    // บันทึกการล็อกอิน
                    await UpdateEmployeeLastLogin(oeeEmployee.WindowsLogin);
                    
                    return new AuthResponseDto
                    {
                        Success = true,
                        User = new UserDto
                        {
                            EmpId = oeeEmployee.EmployeeID,
                            Name = oeeEmployee.DisplayName,
                            Email = oeeEmployee.Email,
                            Role = oeeEmployee.AccessLevel, // 'OPERATOR', 'SUPERVISOR', 'ADMIN'
                            Unit = oeeEmployee.DepartmentCode,
                            Department = oeeEmployee.CostCenter?.CostCenterName,
                            DefaultMachineId = oeeEmployee.DefaultMachineID,
                            DefaultMachineName = oeeEmployee.DefaultMachine?.MachineName,
                            IsAllowed = oeeEmployee.IsAllowed
                        },
                        WindowsUser = new WindowsUserDto
                        {
                            Name = windowsIdentity,
                            Domain = domain,
                            Username = username,
                            Photo = await GetUserPhotoFromAD(domain, username) 
                                     ?? AppConstants.UserDefaults.DEFAULT_USER_PHOTO
                        }
                    };
                }

                // 2. ถ้าไม่เจอใน EmployeeDetails (ระบบเก่า) ให้ตรวจสอบใน Employees
                if (OperatingSystem.IsWindows() && domain.Equals("IRPC", StringComparison.OrdinalIgnoreCase))
                {
                    using (var context = new PrincipalContext(ContextType.Domain, domain))
                    {
                        var userPrincipal = UserPrincipal.FindByIdentity(
                            context,
                            IdentityType.SamAccountName,
                            username
                        );

                        if (userPrincipal != null && !string.IsNullOrEmpty(userPrincipal.EmailAddress))
                        {
                            var employee = await _context.Employees
                                .FirstOrDefaultAsync(e => e.Email.ToLower() == userPrincipal.EmailAddress.ToLower());

                            if (employee != null)
                            {
                                _logger.LogInformation("[AuthService] Found in Employees table: {Name}", employee.FullNameEN);
                                
                                // สร้าง entry ใน EmployeeDetails (รอ approval)
                                await CreatePendingEmployeeEntry(windowsIdentity, employee, userPrincipal);
                                
                                return new AuthResponseDto
                                {
                                    Success = false,
                                    Message = "รอการอนุมัติสิทธิ์จากผู้ดูแลระบบ",
                                    User = new UserDto
                                    {
                                        EmpId = employee.EmpId,
                                        Name = employee.FullNameEN,
                                        Email = employee.Email,
                                        Role = "PENDING",
                                        Unit = employee.Unit ?? string.Empty
                                    },
                                    WindowsUser = new WindowsUserDto
                                    {
                                        Name = userPrincipal.DisplayName ?? windowsIdentity,
                                        Domain = domain,
                                        Username = username,
                                        Photo = await GetUserPhotoFromAD(domain, username)
                                                 ?? AppConstants.UserDefaults.DEFAULT_USER_PHOTO
                                    }
                                };
                            }
                        }
                    }
                }

                // 3. ไม่เจอผู้ใช้ในระบบใดๆ
                _logger.LogWarning("[AuthService] User not found: {Identity}", windowsIdentity);
                return CreateUnauthenticatedResponse("User not found in system");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[AuthService] Error in GetCurrentUser");
                return CreateUnauthenticatedResponse(ex.Message);
            }
        }

        /// <summary>
        /// ดึงรูปโปรไฟล์จาก Active Directory
        /// </summary>
        [SupportedOSPlatform("windows")]
        private async Task<string?> GetUserPhotoFromAD(string domain, string username)
        {
            try
            {
                if (!OperatingSystem.IsWindows())
                    return null;

                using (var context = new PrincipalContext(ContextType.Domain, domain))
                {
                    var userPrincipal = UserPrincipal.FindByIdentity(context, username);
                    if (userPrincipal != null)
                    {
                        var de = userPrincipal.GetUnderlyingObject() as DirectoryEntry;
                        if (de?.Properties.Contains("thumbnailPhoto") == true)
                        {
                            var photoBytes = de.Properties["thumbnailPhoto"].Value as byte[];
                            if (photoBytes?.Length > 0)
                            {
                                return $"data:image/jpeg;base64,{Convert.ToBase64String(photoBytes)}";
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "[AuthService] Cannot get photo from AD for {Username}", username);
            }

            return null;
        }

        /// <summary>
        /// อัพเดทเวลาล็อกอินล่าสุด
        /// </summary>
        private async Task UpdateEmployeeLastLogin(string windowsLogin)
        {
            try
            {
                var employee = await _context.EmployeeDetails
                    .FirstOrDefaultAsync(e => e.WindowsLogin == windowsLogin);

                if (employee != null)
                {
                    employee.LastLogin = DateTime.Now;
                    employee.LoginCount = (employee.LoginCount ?? 0) + 1;
                    if (employee.FirstLogin == null)
                        employee.FirstLogin = DateTime.Now;

                    await _context.SaveChangesAsync();
                    _logger.LogDebug("[AuthService] Updated last login for {User}", windowsLogin);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[AuthService] Error updating last login for {User}", windowsLogin);
            }
        }

        /// <summary>
        /// สร้าง pending entry สำหรับพนักงานใหม่
        /// </summary>
        private async Task CreatePendingEmployeeEntry(string windowsLogin, Employee employee, UserPrincipal userPrincipal)
        {
            try
            {
                // ตรวจสอบว่ามีอยู่แล้วหรือไม่
                var existing = await _context.EmployeeDetails
                    .FirstOrDefaultAsync(e => e.WindowsLogin == windowsLogin);

                if (existing == null)
                {
                    var employeeDetail = new EmployeeDetails
                    {
                        WindowsLogin = windowsLogin,
                        DisplayName = userPrincipal.DisplayName ?? employee.FullNameEN,
                        Email = userPrincipal.EmailAddress ?? employee.Email,
                        EmployeeID = employee.EmpId,
                        DepartmentCode = employee.Unit,
                        AccessLevel = "PENDING",
                        IsAllowed = false,
                        FirstLogin = DateTime.Now,
                        CreatedAt = DateTime.Now
                    };

                    _context.EmployeeDetails.Add(employeeDetail);
                    await _context.SaveChangesAsync();

                    _logger.LogInformation("[AuthService] Created pending entry for {User}", windowsLogin);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[AuthService] Error creating pending entry for {User}", windowsLogin);
            }
        }

        /// <summary>
        /// แยก domain และ username จาก Windows Identity
        /// </summary>
        private (string Domain, string Username) ParseWindowsIdentity(string windowsIdentity)
        {
            var parts = windowsIdentity.Split('\\');
            if (parts.Length == 2)
            {
                return (parts[0], parts[1]);
            }
            return ("", windowsIdentity);
        }

        /// <summary>
        /// สร้าง response สำหรับผู้ใช้ที่ไม่ authenticated
        /// </summary>
        private AuthResponseDto CreateUnauthenticatedResponse(string message = "Not authenticated")
        {
            return new AuthResponseDto
            {
                Success = false,
                Message = message,
                WindowsUser = new WindowsUserDto
                {
                    Name = string.Empty,
                    Domain = string.Empty,
                    Username = string.Empty,
                    Photo = AppConstants.UserDefaults.DEFAULT_USER_PHOTO
                }
            };
        }

        /// <summary>
        /// ตรวจสอบว่า user มีสิทธิ์ตาม role ที่ต้องการหรือไม่
        /// </summary>
        public async Task<bool> CheckUserPermission(string windowsIdentity, string requiredRole)
        {
            try
            {
                var authResponse = await GetCurrentUserAsync(windowsIdentity);
                if (!authResponse.Success || authResponse.User == null)
                    return false;

                // Role hierarchy
                var roleHierarchy = new Dictionary<string, int>
                {
                    ["OPERATOR"] = 1,
                    ["SUPERVISOR"] = 2,
                    ["ADMIN"] = 3
                };

                var userRole = authResponse.User.Role?.ToUpper();
                var requiredRoleLevel = requiredRole.ToUpper();

                if (!roleHierarchy.ContainsKey(userRole) || !roleHierarchy.ContainsKey(requiredRoleLevel))
                    return false;

                return roleHierarchy[userRole] >= roleHierarchy[requiredRoleLevel];
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[AuthService] Error checking user permission");
                return false;
            }
        }

        // เมธอดอื่นๆ ที่มีอยู่เดิม...
        [SupportedOSPlatform("windows")]
        public async Task<AuthResponseDto> GetCurrentUserWithPhotoAsync(string? windowsIdentity)
        {
            // Implementation เดิมหรือปรับปรุงตามด้านบน
            return await GetCurrentUserAsync(windowsIdentity);
        }

        public Task<AuthResponseDto> ValidateUserAsync(LoginModel loginModel)
        {
            throw new NotImplementedException();
        }

        public string GetUserDisplayName(string username)
        {
            throw new NotImplementedException();
        }
    }
}