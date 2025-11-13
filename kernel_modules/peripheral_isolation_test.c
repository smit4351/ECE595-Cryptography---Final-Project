#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/io.h>
#include <linux/ioport.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("ECE595 Research Team");
MODULE_DESCRIPTION("Peripheral Isolation Test for TrustZone");
MODULE_VERSION("1.0");

#define PROC_NAME "peripheral_isolation_test"

/* BCM2835 (RPi3) Peripheral Base Addresses */
#define BCM2835_PERI_BASE    0x3F000000
#define USB_BASE_OFFSET      0x00980000  // USB EHCI host controller
#define EMMC_BASE_OFFSET     0x00300000  // EMMC controller (SD card)
#define GPIO_BASE_OFFSET     0x00200000  // GPIO
#define DMA_BASE_OFFSET      0x00007000  // DMA controller

/* Test results */
struct peripheral_test_result {
    char peripheral_name[32];
    bool can_map_memory;
    bool can_initiate_dma;
    bool isolation_bypass_possible;
    unsigned long test_address;
    int error_code;
};

static struct peripheral_test_result test_results[4];
static int num_tests = 0;
static struct proc_dir_entry *proc_entry;

/* Test if peripheral can be mapped */
static int test_peripheral_mapping(const char *name, unsigned long phys_addr, size_t size)
{
    void __iomem *virt_addr;
    struct peripheral_test_result *result = &test_results[num_tests++];
    
    pr_info("[PERIPH_TEST] Testing: %s (0x%lx, %zu bytes)\n", name, phys_addr, size);
    
    strncpy(result->peripheral_name, name, sizeof(result->peripheral_name) - 1);
    result->test_address = phys_addr;
    result->can_map_memory = false;
    result->can_initiate_dma = false;
    result->isolation_bypass_possible = false;
    
    // Try to map peripheral
    virt_addr = ioremap(phys_addr, size);
    if (!virt_addr) {
        pr_warn("[PERIPH_TEST] ✗ %s: Cannot map memory\n", name);
        result->error_code = -ENOMEM;
        return -ENOMEM;
    }
    
    result->can_map_memory = true;
    pr_info("[PERIPH_TEST] %s: Successfully mapped (virt: %p)\n", name, virt_addr);
    
    // Check if we can read control registers
    u32 control_reg = ioread32(virt_addr);
    pr_info("[PERIPH_TEST]   Control Register Value: 0x%08x\n", control_reg);
    
    // Check for DMA capability (look for DMA enable bits)
    if (control_reg & 0x1) {  // Common DMA enable bit
        result->can_initiate_dma = true;
        pr_warn("[PERIPH_TEST] %s: DMA CAPABILITY DETECTED!\n", name);
        
        // If peripheral can do DMA, isolation may be bypassable
        result->isolation_bypass_possible = true;
        pr_warn("[PERIPH_TEST] %s: ISOLATION BYPASS POSSIBLE\n", name);
    } else {
        pr_info("[PERIPH_TEST]   No DMA capability detected\n");
    }
    
    iounmap(virt_addr);
    pr_info("[PERIPH_TEST] Test complete: %s\n", result->isolation_bypass_possible ? "VULNERABLE" : "OK");
    return 0;
}

/* Test USB controller */
static void test_usb_peripheral(void)
{
    pr_info("[PERIPH_TEST] === Testing USB Controller ===\n");
    test_peripheral_mapping("USB", BCM2835_PERI_BASE + USB_BASE_OFFSET, 0x1000);
}

/* Test EMMC controller */
static void test_emmc_peripheral(void)
{
    pr_info("[PERIPH_TEST] === Testing EMMC Controller ===\n");
    test_peripheral_mapping("EMMC", BCM2835_PERI_BASE + EMMC_BASE_OFFSET, 0x1000);
}

/* Test GPIO */
static void test_gpio_peripheral(void)
{
    pr_info("[PERIPH_TEST] === Testing GPIO ===\n");
    test_peripheral_mapping("GPIO", BCM2835_PERI_BASE + GPIO_BASE_OFFSET, 0x1000);
}

/* Test DMA controller */
static void test_dma_peripheral(void)
{
    pr_info("[PERIPH_TEST] === Testing DMA Controller ===\n");
    test_peripheral_mapping("DMA", BCM2835_PERI_BASE + DMA_BASE_OFFSET, 0x1000);
}

/* /proc interface read */
static ssize_t proc_read(struct file *file, char __user *ubuf,
                         size_t count, loff_t *ppos)
{
    char buffer[1024];
    int len = 0;
    int i;
    
    len += snprintf(buffer + len, sizeof(buffer) - len,
                   "=== Peripheral Isolation Test Results ===\n\n");
    
    for (i = 0; i < num_tests; i++) {
        struct peripheral_test_result *r = &test_results[i];
        
        len += snprintf(buffer + len, sizeof(buffer) - len,
                       "Peripheral: %s\n"
                       "  Address: 0x%lx\n"
                       "  Can Map: %s\n"
                       "  DMA Capable: %s\n"
                       "  Isolation Bypass Possible: %s\n\n",
                       r->peripheral_name,
                       r->test_address,
                       r->can_map_memory ? "YES" : "NO",
                       r->can_initiate_dma ? "YES" : "NO",
                       r->isolation_bypass_possible ? "YES" : "NO");
    }
    
    if (num_tests == 0) {
        len += snprintf(buffer + len, sizeof(buffer) - len,
                       "No tests run yet.\n"
                       "Use: echo 'test <peripheral>' > /proc/peripheral_isolation_test\n"
                       "Options: usb, emmc, gpio, dma, all\n");
    }
    
    return simple_read_from_buffer(ubuf, count, ppos, buffer, len);
}

/* /proc interface write */
static ssize_t proc_write(struct file *file, const char __user *ubuf,
                          size_t count, loff_t *ppos)
{
    char cmd[64];
    
    if (count >= sizeof(cmd))
        return -EINVAL;
    
    if (copy_from_user(cmd, ubuf, count))
        return -EFAULT;
    
    cmd[count] = '\0';
    
    // Reset test count
    num_tests = 0;
    
    if (strstr(cmd, "usb")) {
        test_usb_peripheral();
    } else if (strstr(cmd, "emmc")) {
        test_emmc_peripheral();
    } else if (strstr(cmd, "gpio")) {
        test_gpio_peripheral();
    } else if (strstr(cmd, "dma")) {
        test_dma_peripheral();
    } else if (strstr(cmd, "all") || strstr(cmd, "start")) {
        test_usb_peripheral();
        test_emmc_peripheral();
        test_gpio_peripheral();
        test_dma_peripheral();
    } else if (strstr(cmd, "reset")) {
        num_tests = 0;
        pr_info("[PERIPH_TEST] Results reset\n");
    }
    
    return count;
}

static const struct proc_ops proc_fops = {
    .proc_read = proc_read,
    .proc_write = proc_write,
};

static int __init peripheral_test_init(void)
{
    pr_info("[PERIPH_TEST] Initializing peripheral isolation test module\n");
    
    proc_entry = proc_create(PROC_NAME, 0666, NULL, &proc_fops);
    if (!proc_entry) {
        pr_err("[PERIPH_TEST] Failed to create /proc entry\n");
        return -ENOMEM;
    }
    
    pr_info("[PERIPH_TEST] Module loaded. Use: echo 'test all' > /proc/%s\n", PROC_NAME);
    return 0;
}

static void __exit peripheral_test_exit(void)
{
    if (proc_entry)
        proc_remove(proc_entry);
    
    pr_info("[PERIPH_TEST] Module unloaded\n");
}

module_init(peripheral_test_init);
module_exit(peripheral_test_exit);
