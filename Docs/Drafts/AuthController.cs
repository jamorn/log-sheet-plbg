using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using BackendAPI.Services.Interfaces;
using BackendAPI.Middleware;

namespace BackendAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;
        private readonly ILogger<AuthController> _logger;

        public AuthController(IAuthService authService, ILogger<AuthController> logger)
        {
            _authService = authService;
            _logger = logger;
        }

        [HttpGet("current-user")]
        public async Task<IActionResult> GetCurrentUser()
        {
            try
            {
                // ใช้ Middleware ที่ดึงข้อมูลแล้ว
                var authResponse = OeeAuthMiddleware.GetAuthResponse(HttpContext);
                
                if (authResponse == null)
                {
                    // Fallback: เรียก AuthService โดยตรง
                    var windowsIdentity = HttpContext.User.Identity?.Name;
                    authResponse = await _authService.GetCurrentUserAsync(windowsIdentity);
                }

                if (!authResponse.Success)
                {
                    return Unauthorized(new
                    {
                        success = false,
                        message = authResponse.Message,
                        windowsUser = authResponse.WindowsUser
                    });
                }

                return Ok(new
                {
                    success = true,
                    user = authResponse.User,
                    windowsUser = authResponse.WindowsUser
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in GetCurrentUser endpoint");
                return StatusCode(500, new
                {
                    success = false,
                    message = "Internal server error"
                });
            }
        }

        [HttpGet("check-permission/{requiredRole}")]
        [Authorize]
        public async Task<IActionResult> CheckPermission(string requiredRole)
        {
            try
            {
                var windowsIdentity = HttpContext.User.Identity?.Name;
                var hasPermission = await _authService.CheckUserPermission(windowsIdentity, requiredRole);

                return Ok(new
                {
                    hasPermission,
                    requiredRole,
                    userRole = User.FindFirst(ClaimTypes.Role)?.Value
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking permission");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpGet("test-auth")]
        [Authorize(Policy = "OperatorOnly")]
        public IActionResult TestAuth()
        {
            var userClaims = User.Claims.Select(c => new { c.Type, c.Value }).ToList();
            
            return Ok(new
            {
                message = "Authentication successful!",
                user = User.Identity?.Name,
                claims = userClaims,
                isAuthenticated = User.Identity?.IsAuthenticated
            });
        }
    }
}