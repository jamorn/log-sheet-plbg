using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using System.Threading.Tasks;
using System.Security.Claims;
using BackendAPI.Services.Interfaces;

namespace BackendAPI.Middleware
{
    public class OeeAuthMiddleware
    {
        private readonly RequestDelegate _next;

        public OeeAuthMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context, IAuthService authService)
        {
            // 1. ดึง Windows Identity
            string? windowsIdentity = context.User.Identity?.Name;
            
            // 2. Development Mode: ตรวจสอบ header X-Test-User
            if (context.Request.Headers.TryGetValue("X-Test-User", out var testUserHeader))
            {
                windowsIdentity = $"TESTDOMAIN\\{testUserHeader}";
                _logger.LogDebug("[OeeAuthMiddleware] Using test user: {User}", testUserHeader);
            }

            // 3. เรียก AuthService เพื่อดึงข้อมูลผู้ใช้
            var authResponse = await authService.GetCurrentUserAsync(windowsIdentity);

            // 4. สร้าง Claims ตามผลลัพธ์จาก AuthService
            var claims = CreateClaimsFromAuthResponse(authResponse, windowsIdentity);
            
            if (claims.Any())
            {
                var identity = new ClaimsIdentity(claims, "OeeWindowsAuth");
                context.User = new ClaimsPrincipal(identity);
            }

            // 5. เก็บข้อมูลผู้ใช้ใน HttpContext.Items
            context.Items["AuthResponse"] = authResponse;
            context.Items["WindowsIdentity"] = windowsIdentity;

            // 6. ต่อไปยัง Middleware ต่อไป
            await _next(context);
        }

        private List<Claim> CreateClaimsFromAuthResponse(AuthResponseDto authResponse, string? windowsIdentity)
        {
            var claims = new List<Claim>();

            if (!string.IsNullOrEmpty(windowsIdentity))
            {
                claims.Add(new Claim(ClaimTypes.Name, windowsIdentity));
            }

            if (authResponse.Success && authResponse.User != null)
            {
                var user = authResponse.User;
                
                claims.Add(new Claim(ClaimTypes.NameIdentifier, user.EmpId ?? "0"));
                claims.Add(new Claim(ClaimTypes.Role, user.Role ?? "GUEST"));
                claims.Add(new Claim("DisplayName", user.Name ?? "Unknown"));
                claims.Add(new Claim("Email", user.Email ?? ""));
                claims.Add(new Claim("IsAllowed", "true"));
                
                if (!string.IsNullOrEmpty(user.Unit))
                    claims.Add(new Claim("Unit", user.Unit));
                
                if (!string.IsNullOrEmpty(user.Department))
                    claims.Add(new Claim("Department", user.Department));
                
                if (user.DefaultMachineId.HasValue)
                    claims.Add(new Claim("DefaultMachineId", user.DefaultMachineId.Value.ToString()));
            }
            else
            {
                // User ไม่ authenticated หรือไม่มีสิทธิ์
                claims.Add(new Claim(ClaimTypes.Role, "UNAUTHORIZED"));
                claims.Add(new Claim("IsAllowed", "false"));
            }

            return claims;
        }

        // Extension method สำหรับดึง AuthResponse จาก HttpContext
        public static AuthResponseDto? GetAuthResponse(HttpContext context)
        {
            return context.Items["AuthResponse"] as AuthResponseDto;
        }

        // Extension method สำหรับดึง Windows Identity จาก HttpContext
        public static string? GetWindowsIdentity(HttpContext context)
        {
            return context.Items["WindowsIdentity"] as string;
        }
    }

    // Extension method สำหรับใช้งานง่าย
    public static class OeeAuthMiddlewareExtensions
    {
        public static IApplicationBuilder UseOeeAuth(this IApplicationBuilder builder)
        {
            return builder.UseMiddleware<OeeAuthMiddleware>();
        }
    }
}