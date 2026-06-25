export default function MyPayslipPage() {
  return (
    <>
      <div className="page-header">
        <div>
          <div className="page-title">My Payslips</div>
          <div className="page-sub">View and download your monthly payslips</div>
        </div>
      </div>
      <div className="empty-state">
        <i className="ti ti-receipt" />
        <h3>Payroll module coming soon</h3>
        <p>Your payslips will appear here once the payroll module is activated.</p>
      </div>
    </>
  );
}
