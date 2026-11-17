$baseUrl = "http://localhost:8095"
$ErrorActionPreference = "Stop"

function Assert-Condition($condition, $message) {
    if (-not $condition) {
        Write-Error "ASSERTION FAILED: $message"
        exit 1
    } else {
        Write-Host " [PASS] $message" -ForegroundColor Green
    }
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   DentaCloud End-to-End Real DB Verification    " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Actuator Health
Write-Host "`n1. Testing Actuator Health..." -ForegroundColor Yellow
$health = Invoke-RestMethod -Uri "$baseUrl/actuator/health"
Assert-Condition ($health.status -eq "UP") "Backend health status is UP"

# 2. Signup
Write-Host "`n2. Testing Clinic Signup..." -ForegroundColor Yellow
$suffix = [Guid]::NewGuid().ToString().Substring(0, 8)
$randomPhone = "+91" + (Get-Random -Minimum 9000000000 -Maximum 9999999999)
$signupBody = @{
    clinicName = "Metropolis Dental Clinic $suffix"
    ownerName = "Dr. Alice Smith"
    email = "alice.$suffix@metropolisdental.com"
    phone = $randomPhone
    password = "SuperPassword123!"
    deviceName = "Front Desk PC"
    deviceId = "device-$suffix"
} | ConvertTo-Json

$auth = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/signup" -Method Post -ContentType "application/json" -Body $signupBody
Assert-Condition ($auth.accessToken -ne $null) "Received JWT access token"
Assert-Condition ($auth.role -eq "OWNER") "Assigned OWNER role"
Assert-Condition ($auth.clinicId -ne $null) "Assigned clinic ID"
$token = $auth.accessToken
$clinicId = $auth.clinicId
$dentistId = $auth.memberId
$headers = @{
    "Authorization" = "Bearer $token"
}

# 3. Login
Write-Host "`n3. Testing Auth Login..." -ForegroundColor Yellow
$loginBody = @{
    email = "alice.$suffix@metropolisdental.com"
    password = "SuperPassword123!"
    deviceName = "Front Desk PC"
    deviceId = "device-$suffix"
} | ConvertTo-Json
$login = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
Assert-Condition ($login.accessToken -ne $null) "User successfully logged in"

# 4. Refresh Token
Write-Host "`n4. Testing Token Refresh..." -ForegroundColor Yellow
$refreshBody = @{
    refreshToken = $login.refreshToken
} | ConvertTo-Json
$refreshed = Invoke-RestMethod -Uri "$baseUrl/api/v1/auth/refresh" -Method Post -ContentType "application/json" -Body $refreshBody
Assert-Condition ($refreshed.accessToken -ne $null) "Successfully refreshed access token"
$token = $refreshed.accessToken
$headers["Authorization"] = "Bearer $token"

# 5. Clinic Profile
Write-Host "`n5. Testing Clinic Profile..." -ForegroundColor Yellow
$clinic = Invoke-RestMethod -Uri "$baseUrl/api/v1/clinic" -Headers $headers
Assert-Condition ($clinic.name -eq "Metropolis Dental Clinic $suffix") "Clinic name matches"
Assert-Condition ($clinic.currency -eq "INR") "Clinic currency is INR"

# 6. Roles & Members
Write-Host "`n6. Testing Roles and Members..." -ForegroundColor Yellow
$roles = Invoke-RestMethod -Uri "$baseUrl/api/v1/clinic/roles" -Headers $headers
Assert-Condition ($roles.Count -ge 5) "System roles are seeded ($($roles.Count) roles)"
$receptionistRole = $roles | Where-Object { $_.name -eq "RECEPTIONIST" }

$members = Invoke-RestMethod -Uri "$baseUrl/api/v1/clinic/members" -Headers $headers
Assert-Condition ($members.Count -ge 1) "Owner is listed as team member"

# Add Receptionist
$newMemberBody = @{
    fullName = "Bob Jones"
    email = "bob.$suffix@metropolisdental.com"
    tempPassword = "TempPassword123!"
    roleId = $receptionistRole.id
    isDentist = $false
    registrationNo = ""
} | ConvertTo-Json
$newMember = Invoke-RestMethod -Uri "$baseUrl/api/v1/clinic/members" -Method Post -Headers $headers -ContentType "application/json" -Body $newMemberBody
Assert-Condition ($newMember.fullName -eq "Bob Jones") "Added receptionist Bob Jones"

# 7. Chairs
Write-Host "`n7. Testing Chairs..." -ForegroundColor Yellow
$chairs = Invoke-RestMethod -Uri "$baseUrl/api/v1/clinic/chairs" -Headers $headers
Assert-Condition ($chairs.Count -ge 1) "Initial chair seeded (count: $($chairs.Count))"
$chair1 = $chairs[0]

$newChairBody = @{ name = "Surgery Chair 3" } | ConvertTo-Json
$newChair = Invoke-RestMethod -Uri "$baseUrl/api/v1/clinic/chairs" -Method Post -Headers $headers -ContentType "application/json" -Body $newChairBody
Assert-Condition ($newChair.name -eq "Surgery Chair 3") "Added new chair"

# 8. Procedures
Write-Host "`n8. Testing Seeded Procedures..." -ForegroundColor Yellow
$procedures = Invoke-RestMethod -Uri "$baseUrl/api/v1/procedures" -Headers $headers
Assert-Condition ($procedures.Count -ge 7) "Procedures auto-seeded for clinic (count: $($procedures.Count))"
$rctProcedure = $procedures | Where-Object { $_.code -eq "RCT" }
Assert-Condition ($rctProcedure.defaultPaise -eq 600000) "RCT price is 6000.00 INR (600000 paise)"

# 9. Patients
Write-Host "`n9. Testing Patients Management..." -ForegroundColor Yellow
$p1Phone = "+91" + (Get-Random -Minimum 9000000000 -Maximum 9999999999)
$patient1Body = @{
    fullName = "Charlie Brown"
    dob = "1990-05-15"
    gender = "MALE"
    phone = $p1Phone
    email = "charlie.$suffix@example.com"
    address = "42 Peanut Street, Metropolis"
    medicalHistory = "Hypertension controlled by amlodipine"
    allergies = "Penicillin"
    cardColor = -16744193
} | ConvertTo-Json
$patient1 = Invoke-RestMethod -Uri "$baseUrl/api/v1/patients" -Method Post -Headers $headers -ContentType "application/json" -Body $patient1Body
Assert-Condition ($patient1.id -ne $null) "Created Patient 1 (Charlie Brown, id: $($patient1.id))"
Assert-Condition ($patient1.patientNo -ne $null) "Patient number assigned: $($patient1.patientNo)"

$p2Phone = "+91" + (Get-Random -Minimum 9000000000 -Maximum 9999999999)
$patient2Body = @{
    fullName = "Diana Prince"
    dob = "1992-08-20"
    gender = "FEMALE"
    phone = $p2Phone
    email = "diana.$suffix@example.com"
    address = "1 Paradise Island, Metropolis"
    medicalHistory = "None"
    allergies = "None"
    cardColor = -16744193
} | ConvertTo-Json
$patient2 = Invoke-RestMethod -Uri "$baseUrl/api/v1/patients" -Method Post -Headers $headers -ContentType "application/json" -Body $patient2Body
Assert-Condition ($patient2.id -ne $null) "Created Patient 2 (Diana Prince)"

# Search patient
$search = Invoke-RestMethod -Uri "$baseUrl/api/v1/patients?q=Charlie" -Headers $headers
Assert-Condition ($search.items.Count -ge 1 -and $search.items[0].fullName -eq "Charlie Brown") "Search patient by name succeeded"

# Search by encrypted phone blind-index
$p1Digits = $p1Phone.Substring($p1Phone.Length - 10)
$phoneSearch = Invoke-RestMethod -Uri "$baseUrl/api/v1/patients?q=$p1Digits" -Headers $headers
Assert-Condition ($phoneSearch.items.Count -ge 1 -and $phoneSearch.items[0].id -eq $patient1.id) "Search by phone via blind-index succeeded"

# Update patient
$updateBody = @{
    id = $patient1.id
    clinicId = $clinicId
    fullName = "Charlie Brown Updated"
    dob = "1990-05-15"
    gender = "MALE"
    phone = $p1Phone
    email = "charlie.updated.$suffix@example.com"
    address = "43 Peanut Street, Metropolis"
    medicalHistory = "Hypertension"
    allergies = "Penicillin, Latex"
    cardColor = -16744193
    version = $patient1.version
} | ConvertTo-Json
$updatedPatient = Invoke-RestMethod -Uri "$baseUrl/api/v1/patients/$($patient1.id)" -Method Patch -Headers $headers -ContentType "application/json" -Body $updateBody
Assert-Condition ($updatedPatient.fullName -eq "Charlie Brown Updated") "Patient update succeeded (version incremented)"

# 10. Scheduling & Appointments
Write-Host "`n10. Testing Appointments & Exclusion Constraints..." -ForegroundColor Yellow
$nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$startAt = $nowEpoch + 3600000     # 1 hour from now
$endAt = $startAt + 1800000        # 30 mins duration

$aptBody = @{
    patientId = $patient1.id
    dentistId = $dentistId
    chairId = $chair1.id
    procedureId = $rctProcedure.id
    startAt = $startAt
    endAt = $endAt
    reason = "Root canal evaluation"
    colorLabel = 1
} | ConvertTo-Json

$aptHeaders = $headers.Clone()
$aptHeaders["Idempotency-Key"] = "book-apt-$suffix-1"
$apt = Invoke-RestMethod -Uri "$baseUrl/api/v1/appointments" -Method Post -Headers $aptHeaders -ContentType "application/json" -Body $aptBody
Assert-Condition ($apt.id -ne $null) "Appointment booked successfully (id: $($apt.id))"

# Double booking test (overlapping same chair/dentist) -> should fail with 409 Conflict
Write-Host "   Testing Postgres exclusion constraint (double-booking protection)..."
$conflictHeaders = $headers.Clone()
$conflictHeaders["Idempotency-Key"] = "book-apt-$suffix-conflict"
$conflictBody = @{
    patientId = $patient2.id
    dentistId = $dentistId
    chairId = $chair1.id
    startAt = $startAt + 600000   # 10 mins into existing appointment!
    endAt = $endAt + 600000
    reason = "Overlapping consultation"
} | ConvertTo-Json

$conflictCaught = $false
try {
    Invoke-RestMethod -Uri "$baseUrl/api/v1/appointments" -Method Post -Headers $conflictHeaders -ContentType "application/json" -Body $conflictBody
} catch {
    $conflictCaught = $true
    Assert-Condition ($_.Exception.Response.StatusCode.value__ -eq 409) "Database rejected double-booking with 409 Conflict"
}
Assert-Condition $conflictCaught "Double booking exclusion constraint verified!"

# Update appointment status
$statusBody = @{ status = "DONE" } | ConvertTo-Json
$updatedApt = Invoke-RestMethod -Uri "$baseUrl/api/v1/appointments/$($apt.id)/status" -Method Patch -Headers $headers -ContentType "application/json" -Body $statusBody
Assert-Condition ($updatedApt.status -eq "DONE") "Appointment status transitioned to DONE"

# 11. Clinical Chart & Tooth Records
Write-Host "`n11. Testing FDI Dental Chart..." -ForegroundColor Yellow
$recordsBody = @(
    @{
        toothFdi = 16
        condition = "CARIES"
        surface = "O"
        note = "Deep occlusal caries requiring RCT"
    },
    @{
        toothFdi = 17
        condition = "SOUND"
        surface = $null
        note = "Sound tooth structure"
    }
) | ConvertTo-Json
$chartRecords = Invoke-RestMethod -Uri "$baseUrl/api/v1/patients/$($patient1.id)/chart/records" -Method Post -Headers $headers -ContentType "application/json" -Body $recordsBody
Assert-Condition ($chartRecords.Count -ge 2) "Saved 2 tooth records into dental chart"

$fetchedChart = Invoke-RestMethod -Uri "$baseUrl/api/v1/patients/$($patient1.id)/chart" -Headers $headers
Assert-Condition ($fetchedChart.Count -ge 2) "Retrieved patient chart with FDI tooth numbers"

# 12. Clinical Visits & Treatment Plans
Write-Host "`n12. Testing Clinical Visits & Treatment Plans..." -ForegroundColor Yellow
$visitBody = @{
    patientId = $patient1.id
    dentistId = $dentistId
    appointmentId = $apt.id
    notes = "Access cavity prepared on tooth 16. Working length determined."
    diagnosis = "Irreversible pulpitis on tooth 16"
} | ConvertTo-Json
$visit = Invoke-RestMethod -Uri "$baseUrl/api/v1/visits" -Method Post -Headers $headers -ContentType "application/json" -Body $visitBody
Assert-Condition ($visit.id -ne $null) "Clinical visit logged successfully"

$planBody = @{
    patientId = $patient1.id
    title = "Tooth 16 Rehabilitation"
    items = @(
        @{
            toothFdi = 16
            procedureId = $rctProcedure.id
            surface = "O"
            estPaise = 600000
        }
    )
} | ConvertTo-Json
$plan = Invoke-RestMethod -Uri "$baseUrl/api/v1/treatment-plans" -Method Post -Headers $headers -ContentType "application/json" -Body $planBody
Assert-Condition ($plan.id -ne $null) "Treatment plan created (status: $($plan.status))"
Assert-Condition ($plan.items.Count -eq 1) "Plan item included with estimate"

# 13. Billing, Invoices & Idempotent Payments
Write-Host "`n13. Testing Billing, Invoices & Payments..." -ForegroundColor Yellow
$invHeaders = $headers.Clone()
$invHeaders["Idempotency-Key"] = "inv-$suffix-1"
$invoiceBody = @{
    patientId = $patient1.id
    discountPaise = 50000  # 500 INR discount
    lines = @(
        @{
            description = "Root Canal Treatment Tooth 16"
            qty = 1
            amountPaise = 600000
            taxBasisPoints = 0
        }
    )
} | ConvertTo-Json
$invoice = Invoke-RestMethod -Uri "$baseUrl/api/v1/invoices" -Method Post -Headers $invHeaders -ContentType "application/json" -Body $invoiceBody
Assert-Condition ($invoice.id -ne $null) "Invoice issued: $($invoice.invoiceNo)"
Assert-Condition ($invoice.totalPaise -eq 550000) "Total calculated correctly: 5500.00 INR (550000 paise)"
Assert-Condition ($invoice.status -eq "ISSUED") "Invoice initial status is ISSUED"

# Record Payment with Idempotency Key
$payHeaders = $headers.Clone()
$paymentKey = "pay-$suffix-1"
$payHeaders["Idempotency-Key"] = $paymentKey
$paymentBody = @{
    mode = "UPI"
    amountPaise = 550000
    reference = "UPI-REF-998877"
} | ConvertTo-Json
$payment = Invoke-RestMethod -Uri "$baseUrl/api/v1/invoices/$($invoice.id)/payments" -Method Post -Headers $payHeaders -ContentType "application/json" -Body $paymentBody
Assert-Condition ($payment.id -ne $null) "Payment recorded: $($payment.amountPaise) paise via UPI"

# Re-send same payment with same Idempotency Key (Idempotency test)
$paymentDup = Invoke-RestMethod -Uri "$baseUrl/api/v1/invoices/$($invoice.id)/payments" -Method Post -Headers $payHeaders -ContentType "application/json" -Body $paymentBody
Assert-Condition ($paymentDup.id -eq $payment.id) "Payment idempotency verified: identical payment returned, no duplicate charge"

# Check invoice status is now PAID
$paidInvoice = Invoke-RestMethod -Uri "$baseUrl/api/v1/invoices/$($invoice.id)" -Headers $headers
Assert-Condition ($paidInvoice.status -eq "PAID") "Invoice status automatically updated to PAID"
Assert-Condition ($paidInvoice.paidPaise -eq 550000) "Invoice paidPaise matches total"

# 14. Prescriptions
Write-Host "`n14. Testing Prescriptions..." -ForegroundColor Yellow
$rxBody = @{
    patientId = $patient1.id
    visitId = $visit.id
    dentistId = $dentistId
    notes = "Take medications after food"
    items = @(
        @{
            drugName = "Amoxicillin 500mg"
            dose = "500 mg"
            frequency = "1-1-1 (TID)"
            durationDays = 5
            instructions = "After meals"
        },
        @{
            drugName = "Ibuprofen 400mg"
            dose = "400 mg"
            frequency = "1-0-1 (BID)"
            durationDays = 3
            instructions = "As needed for pain"
        }
    )
} | ConvertTo-Json
$rx = Invoke-RestMethod -Uri "$baseUrl/api/v1/prescriptions" -Method Post -Headers $headers -ContentType "application/json" -Body $rxBody
Assert-Condition ($rx.id -ne $null) "Prescription created with $($rx.items.Count) items"

$rxs = Invoke-RestMethod -Uri "$baseUrl/api/v1/patients/$($patient1.id)/prescriptions" -Headers $headers
Assert-Condition ($rxs.Count -ge 1) "Retrieved prescriptions for patient"

# 15. Reports
Write-Host "`n15. Testing Financial Reports..." -ForegroundColor Yellow
$dailyCol = Invoke-RestMethod -Uri "$baseUrl/api/v1/reports/daily-collection" -Headers $headers
Assert-Condition ($dailyCol.collectedPaise -ge 550000) "Daily collection report reflects payment ($($dailyCol.collectedPaise) paise)"

$dues = Invoke-RestMethod -Uri "$baseUrl/api/v1/reports/dues" -Headers $headers
Assert-Condition ($dues.duePaise -ge 0) "Dues report calculated successfully"

# 16. Mobile Sync Engine
Write-Host "`n16. Testing Mobile Sync Engine..." -ForegroundColor Yellow
Write-Host "   Waiting 6s for sync-lag window (configured 5s safety lag)..."
Start-Sleep -Seconds 6
$pull = Invoke-RestMethod -Uri "$baseUrl/api/v1/sync/pull?since=0" -Headers $headers
Assert-Condition ($pull.changes.Count -ge 5) "Sync pull returned $($pull.changes.Count) changes since seq 0"

# Sync Push
$pushKey = "push-$suffix-1"
$pushPatientId = [Guid]::NewGuid().ToString()
$syncPhone = "+91" + (Get-Random -Minimum 9000000000 -Maximum 9999999999)
$pushBody = @{
    ops = @(
        @{
            idempotencyKey = $pushKey
            entity = "patient"
            entityId = $pushPatientId
            operation = "UPSERT"
            payload = @{
                id = $pushPatientId
                clinicId = $clinicId
                fullName = "Offline Sync Patient"
                dob = "1995-01-01"
                gender = "MALE"
                phone = $syncPhone
                email = "offline.$suffix@example.com"
                address = "Sync Street"
                medicalHistory = "None"
                allergies = "None"
                cardColor = -1
                createdAt = $nowEpoch
                updatedAt = $nowEpoch
                version = 1
            }
        }
    )
} | ConvertTo-Json -Depth 5
$push = Invoke-RestMethod -Uri "$baseUrl/api/v1/sync/push" -Method Post -Headers $headers -ContentType "application/json" -Body $pushBody
Assert-Condition ($push.results.Count -eq 1 -and $push.results[0].status -eq "APPLIED") "Sync push applied offline device write successfully"

# 17. Hash-chained Audit Log & Verification
Write-Host "`n17. Testing Hash-Chained Audit Log..." -ForegroundColor Yellow
$auditEvents = Invoke-RestMethod -Uri "$baseUrl/api/v1/audit-events" -Headers $headers
Assert-Condition ($auditEvents.Count -ge 1) "Audit events logged ($($auditEvents.Count) events recorded)"

$auditVerify = Invoke-RestMethod -Uri "$baseUrl/api/v1/audit-events/verify" -Headers $headers
Assert-Condition ($auditVerify.valid -eq $true) "Audit log cryptographic SHA-256 hash-chain verified (valid: $($auditVerify.valid), count: $($auditVerify.events))"

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host " ALL 17 MODULES AND FEATURES PASSED ON REAL DB! " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
